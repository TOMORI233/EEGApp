function trialsData = presentStimuli(app)
%PRESENTSTIMULI  Present stimuli by EventFlow (app.params.Evts) + rules.xlsx (filePath).
%
% Visual stimulus rendering is intentionally left blank and delegated to:
%   vis = presentVisualSti(win, winRect, ruleRow, ctx)   % <-- stub + pseudocode inside
%
% Output:
%   trialsData : struct array, each element contains trialIndex and events (per event record)

params    = app.params;
evts      = params.Evts;
rulesPath = app.rulesPath;
fsDevice  = params.fs;

% ----------------------------- defaults -----------------------------
if ~isfield(params,'nRepeat')          , params.nRepeat = 1;               end
if ~isfield(params,'fs')               , params.fs = 384e3;                end
if ~isfield(params,'volumn')           , params.volumn = 0.3;              end
if ~isfield(params,'useSettingnRepeat'), params.useSettingnRepeat = false; end
if ~isfield(params,'triggerType')      , params.triggerType = "None";      end
if ~isfield(params,'address')          , params.address = hex2dec('378');  end
if ~isfield(params,'ioObj')            , params.ioObj = [];                end

triggerType = string(params.triggerType);
ioObj       = params.ioObj;
address     = params.address;

% ----------------------------- current pID -----------------------------
pID = app.pIDList(app.pIDIndex);

% ----------------------------- rules -----------------------------
rules = readtable(rulesPath);
rules = rules(rules.pID == pID, :);
assert(~isempty(rules), "No rules found for pID=%d in %s", pID, rulesPath);

presetParams = {'pID'; 'node0Hint'; 'nodeHint'; 'protocol'; 'code'; 'identifier'; 'group'; ...
    'eventFlow'; 'nRepeat'; 'processFcn'; 'filePath'};
cellfun(@(x) assert(ismember(x, rules.Properties.VariableNames), ...
    "Field %s is required in rules.xlsx", x), presetParams);

rules.identifier = string(rules.identifier);
rules.group      = string(rules.group);
rules.filePath   = string(rules.filePath);

% ----------------------------- normalize event flow -----------------------------
evts = normalizeEventFlow_(evts);

% ----------------------------- identifier -----------------------------
% Search for each identifier defined by event flow in rule file.
% - If no identifier is defined by event flow:
%   1. Make sure that only one stimulus is used in the event flow and identify it as "S1".
%   2. If no identifier is found in rule file, give all stimuli a temporary identifier "S1".
%   3. Check whether there is no more than one cue used. If cue used, identify it as "C1".
%   4. Load a default auditory cue file from `sounds\defaults\cue.wav` as cue.
% - The identifiers in rule file should match those in event flow.
[evts, rules, idInfo] = reconcileIdentifiers_(evts, rules);

% ----------------------------- group -----------------------------
% Default mode:
%   - If all rules.group are empty -> independent randomization (cartesian product across identifiers).
%   - If group exists -> grouped randomization (paired by position within group).
groupInfo = buildGroupInfo_(rules, idInfo);

% ----------------------------- nRepeat (trial repeats) -----------------------------
% rules.nRepeat can be per stimulus row; params.nRepeat is the global fallback.
% For grouped stimuli, enforce equal nRepeat across identifiers within the group (by expanded list length).
idxExpandedById = expandByRepeat_(rules, params.nRepeat, params.useSettingnRepeat, idInfo, groupInfo);

% ----------------------------- trial order -----------------------------
% Create randomized trial order matrix [ntrial x nCol], each column points to a row index in rules.
% - Independent identifiers: cartesian product across identifiers.
% - Grouped identifiers: paired by position inside a group; groups combine by cartesian product.
[trialMat, trialMeta] = buildTrialOrder_(idxExpandedById, idInfo, groupInfo);

ntrial = size(trialMat, 1);

% ----------------------------- inter-trial-interval -----------------------------
% Defined by:
%   ITI(trial) = startJitter(trial) + (time from start event to first non-start event)
ITI = buildITI_(evts, ntrial);

% ----------------------------- real-time monitor -----------------------------
mon = initRealtimeMonitor_(app, rules);

% ----------------------------- preload sounds -----------------------------
% Load sound waves according to [filePath] in rule file (auditory only).
audioDB = preloadAudio_(rules, params.fs);

% ----------------------------- record trial info -----------------------------
temp = cell(size(evts, 1), 1);
evtTemplate = struct("type", temp, "tStart", temp, "tEnd", temp, ...
    "stiName", temp, "code", temp, ...
    "tKeypress", temp, "key", temp);

temp = cell(ntrial, 1);
trialsData = struct("trialIndex", temp, "events", temp);

% ----------------------------- hint sound before experiment -----------------------------
% Each protocol may deliver a voice notice.
% Search `sounds\hint\` for file `[pID].wav|mp3`. If not found, skip.
tryPlayHint_(pID, fsDevice);

% ----------------------------- init PTB -----------------------------
AssertOpenGL;
InitializePsychSound;
PsychPortAudio('Close'); % in case previous phase was terminated

reqlatencyclass = 2;
nChs = 2;
optMode = 1;
pahandle = PsychPortAudio('Open', [], optMode, reqlatencyclass, fsDevice, nChs);
PsychPortAudio('Volume', pahandle, params.volumn);

% To prevent burst sound caused by sudden change from zero
PsychPortAudio('FillBuffer', pahandle, [zeros(1, 10); zeros(1, 10)]);
PsychPortAudio('Start', pahandle, 1, 0, 1);
st = PsychPortAudio('Stop', pahandle, 1, 1); %#ok<NASGU>

% TODO: Init visual (leave blank; open window only if you implement visual)
win = [];
winRect = [];
slack = 0;

cleaner = onCleanup(@()cleanup_());

% ----------------------------- pre-parse choice spec -----------------------------
[choiceWin, validKeycode] = parseChoiceSpec_(evts);

% ----------------------------- start trigger spec -----------------------------
startSpec = parseStartSpec_(evts);   % startSpec.mode, startSpec.keycode
startIdx = find(evts.kind=="start", 1, "first");
assert(~isempty(startIdx), "Start event is required in event flow.");

% ----------------------------- trial loop -----------------------------
t0 = GetSecs;
tPrevEnd = t0;

onsetCell  = cell(ntrial,1);
offsetCell = cell(ntrial,1);
codeCell   = cell(ntrial,1);
pushCell   = cell(ntrial,1);
keyCell    = cell(ntrial,1);

KbGet(32, 20); % Wait for user start
sendMarker_(triggerType, ioObj, address, 1); % task start

for trlIdx = 1:ntrial

    % ---- build per-trial event records ----
    evtRec = evtTemplate;
    for e = 1:height(evts)
        evtRec(e).type = char(evts.kind(e));
        evtRec(e).tStart = NaN;
        evtRec(e).tEnd = NaN;
        evtRec(e).stiName = "";
        evtRec(e).code = NaN;
        evtRec(e).tKeypress = NaN;
        evtRec(e).key = 0;
    end

    % ---- ITI gate before trial ----
    tReady = tPrevEnd + ITI(trlIdx);
    WaitSecs('UntilTime', tReady);
    
    % ---- start event (auto / keyboard) ----
    % We define tTrial0 as the "start time zero" for this trial.
    % - auto    : tTrial0 = tReady (the moment trial is allowed to start)
    % - keyboard: wait for subject keypress after tReady, then tTrial0 = keypress time
    
    if startSpec.mode == "keyboard"
        % optional: ensure clean edge detection
        KbReleaseWait;
        [tKey, keyCode] = KbGet(startSpec.keycode, inf);
    
        tTrial0 = tKey;
    
        % record in start row
        evtRec(startIdx).tStart = tKey;
        evtRec(startIdx).tKeypress = tKey;
        evtRec(startIdx).key = keyCode;
    else
        tTrial0 = tReady;
        evtRec(startIdx).tStart = tReady;
        evtRec(startIdx).code = 1;
    end

    % ---- generate per-event jittered schedule ----
    sch = compileSchedule_(evts, trialMat(trlIdx,:), idInfo, rules, tTrial0);

    % ---- execute schedule in time order ----
    pressT = NaN;
    pressKey = 0;

    for s = 1:height(sch)
        k  = sch.kind(s);
        md = sch.modality(s);
        id = sch.identifier(s);
        tPlan0 = sch.tAbs0(s);
        tPlan1 = sch.tAbs1(s);

        % wait until onset
        if GetSecs < tPlan0
            WaitSecs('UntilTime', max(GetSecs, tPlan0 - 0.002));
        end

        if k=="stimuli" || k=="cue"

            if md=="visual"
                % ================================
                % TODO: present visual stimuli
                % ================================
                % ruleRow is available as sch.ruleRow{s} (1xN table)
                ruleRow = sch.ruleRow{s};

                % Placeholder: build a draw plan (not implemented)
                vis = presentVisualSti(win, winRect, ruleRow, struct( ...
                    "identifier", id, ...
                    "pID", pID, ...
                    "trialIndex", trlIdx, ...
                    "tPlan", tPlan0, ...
                    "params", params)); %#ok<NASGU>

                % ---- record onset (planned) ----
                evtRec(sch.evtIndex(s)).tStart = tPlan0;
                evtRec(sch.evtIndex(s)).tEnd   = tPlan1;

                % If/when implemented, it should draw to backbuffer then Flip at tPlan0.
                % e.g.:
                %   vis.drawFcn(win);
                %   Screen('Flip', win, tPlan0 - slack);

                % ---- marker at event onset ----
                sendMarker_(triggerType, ioObj, address, sch.markerCode(s));

            else
                % ---------------- auditory playback ----------------
                wave = pickWave_(audioDB, id);
                PsychPortAudio('FillBuffer', pahandle, wave);
                PsychPortAudio('Start', pahandle, 1, tPlan0, 0);

                % ---- marker at event onset ----
                sendMarker_(triggerType, ioObj, address, sch.markerCode(s));

                [evtRec(sch.evtIndex(s)).tStart, ~, ~, evtRec(sch.evtIndex(s)).tEnd] = PsychPortAudio('Stop', pahandle, 1, 1);

                evtRec(sch.evtIndex(s)).stiName = char(id);

                % code: use rules.code for this specific row
                rr = sch.ruleRow{s};
                if istable(rr) && ~isempty(rr)
                    evtRec(sch.evtIndex(s)).code = rr.code(1);
                end
            end

        elseif k=="choice"
            % ================================
            % wait for keyboard response (KbGet)
            % ================================
            % Use remaining window from now
            tNow = GetSecs;
            limit = max(0, tPlan1 - tNow);

            KbReleaseWait; % ensure edge detection clean
            [secsPress, keyPress] = KbGet(validKeycode, limit);

            % marker for response
            if keyPress ~= 0
                sendMarker_(triggerType, ioObj, address, find(keyPress == validKeycode) + 1);
            end

            pressT = secsPress;
            pressKey = keyPress;

            evtRec(sch.evtIndex(s)).tKeypress = secsPress;
            evtRec(sch.evtIndex(s)).key = keyPress;
        end
    end

    % ---- estimate trial end ----
    tPrevEnd = GetSecs;

    % ---- store trial data ----
    trialsData(trlIdx).trialIndex = trlIdx;
    trialsData(trlIdx).events = evtRec;

    % ---- build real-time monitor inputs (legacy compatible) ----
    [onsetCell{trlIdx}, offsetCell{trlIdx}, codeCell{trlIdx}] = pickPrimaryStim_(sch);
    pushCell{trlIdx} = pressT;
    keyCell{trlIdx}  = pressKey;

    updateRealtimeMonitor_(mon, app, rules, onsetCell, offsetCell, codeCell, pushCell, keyCell);

    % For termination
    pause(0.1);

    if strcmp(app.status, 'stop')
        return;
    end

end

WaitSecs(4);

if strcmp(app.status, 'start')

    if pID == app.pIDList(end)
        app.AddSubjectButton.Enable = 'on';
        app.SetParamsButton.Enable = 'on';
        app.StartButton.Enable = 'off';
        app.NextButton.Enable = 'off';
        app.StopButton.Enable = 'off';
        app.PhaseSelectPanel.Enable = 'on';
        app.DataPathPanel.Enable = 'on';
        app.StateLabel.Text = 'All experiments are done!';
    else
        app.NextButton.Enable = 'on';
        app.timerInit;
        start(app.mTimer);
    end

    drawnow;
end

return;
end

% =====================================================================
%                              Helpers
% =====================================================================

function cleanup_()
    try PsychPortAudio('Close'); catch, end
    % if visual implemented:
    try Screen('CloseAll'); catch, end
end

function ev = normalizeEventFlow_(ev)
    need = ["kind","modality","tStart","tEnd","jitterA","jitterB","maxDur","identifier"];
    for nm = need
        assert(ismember(nm, ev.Properties.VariableNames), "Evts must have column '%s'.", nm);
    end
    ev.kind = string(ev.kind);
    ev.modality = string(ev.modality);
    ev.identifier = string(ev.identifier);
    
    % Fill missing ends
    for i = 1:height(ev)
        if ev.kind(i)=="start"
            ev.tStart(i) = 0;
            ev.tEnd(i)   = 0;
        elseif ev.kind(i)=="choice"
            if ismember("validWindow", ev.Properties.VariableNames) && isfinite(ev.validWindow(i)) && ev.validWindow(i)>0
                ev.tEnd(i) = ev.tStart(i) + ev.validWindow(i);
            end
        else
            md = ev.maxDur(i);
            if isfinite(md) && md>0
                ev.tEnd(i) = ev.tStart(i) + md;
            end
        end
    end
end

function [ev, rl, info] = reconcileIdentifiers_(ev, rl)
    % Collect identifiers from event flow
    idsFlow = unique(string(ev.identifier(ev.kind=="stimuli" | ev.kind=="cue")), 'stable');
    idsFlow(idsFlow=="") = [];
    
    % If none in flow: enforce single stimulus + optional single cue
    if isempty(idsFlow)
        nStim = sum(ev.kind=="stimuli");
        assert(nStim<=1, "No identifier in event flow, but multiple stimuli events found. Add identifiers.");
        if nStim==1
            ev.identifier(ev.kind=="stimuli") = "S1";
        end
    
        nCue = sum(ev.kind=="cue");
        assert(nCue<=1, "No identifier in event flow, but multiple cue events found. Add identifiers.");
        if nCue==1
            ev.identifier(ev.kind=="cue") = "C1";
        end
        idsFlow = unique(string(ev.identifier(ev.kind=="stimuli" | ev.kind=="cue")), 'stable');
        idsFlow(idsFlow=="") = [];
    end
    
    % If rules.identifier empty: assign all to first stimulus identifier
    if all(rl.identifier=="" | ismissing(rl.identifier))
        if any(ev.kind=="stimuli")
            % assign all sounds to first stimuli identifier
            stimIds = unique(string(ev.identifier(ev.kind=="stimuli")), 'stable');
            stimIds(stimIds=="") = [];
            if isempty(stimIds), stimIds = "S1"; end
            rl.identifier(:) = stimIds(1);
        end
    end
    
    % Ensure flow identifiers exist in rules
    for k = 1:numel(idsFlow)
        if ~any(rl.identifier == idsFlow(k))
            error("Identifier '%s' used in event flow but not found in rules.xlsx for pID=%d.", idsFlow(k), pID);
        end
    end
    
    % Default cue handling if cue exists in flow but no cue identifier in rules
    cueIds = unique(string(ev.identifier(ev.kind=="cue")), 'stable');
    cueIds(cueIds=="") = [];
    if ~isempty(cueIds)
        for k = 1:numel(cueIds)
            if ~any(rl.identifier==cueIds(k))
                % Load default cue into rules as a virtual row
                defCue = fullfile(fileparts(mfilename("fullpath")), "sounds", "defaults", "cue.wav");
                assert(isfile(defCue), "Default cue file not found: %s", defCue);
    
                rr = rl(1,:);
                rr.code = max(rl.code)+1;
                rr.identifier = cueIds(k);
                rr.group = "";
                rr.nRepeat = nan;
                rr.filePath = string(defCue);
                rl = [rl; rr]; %#ok<AGROW>
            end
        end
    end
    
    info = struct();
    info.idsFlow = idsFlow;
    info.idsStim = unique(string(ev.identifier(ev.kind=="stimuli")), 'stable');
    info.idsCue  = unique(string(ev.identifier(ev.kind=="cue")), 'stable');
    info.idsStim(info.idsStim=="") = [];
    info.idsCue(info.idsCue=="") = [];
end

function groupInfo = buildGroupInfo_(rl, idInfo)
    groupInfo = struct();
    groupInfo.hasGroup = any(~(rl.group=="" | ismissing(rl.group)));
    
    % For each identifier, list its groups
    ids = idInfo.idsFlow;
    G = struct();
    for k = 1:numel(ids)
        id = ids(k);
        idx = find(rl.identifier==id);
        g = rl.group(idx);
        g(g=="" | ismissing(g)) = "";
        G.(matlab.lang.makeValidName(char(id))) = unique(g, 'stable');
    end
    groupInfo.byIdGroups = G;
end

function idxExpandedById = expandByRepeat_(rl, nRepeatDefault, useSetting, idInfo, groupInfo)
    ids = idInfo.idsFlow;
    idxExpandedById = struct();
    
    for k = 1:numel(ids)
        id = ids(k);
        idx = find(rl.identifier==id);
    
        % nRepeat per row
        nr = rl.nRepeat(idx);
        if useSetting
            nr(:) = nRepeatDefault;
        else
            nr(isnan(nr)) = nRepeatDefault;
        end
        nr = max(1, round(nr));
    
        % Expand indices
        expanded = [];
        for j = 1:numel(idx)
            expanded = [expanded; repmat(idx(j), nr(j), 1)]; %#ok<AGROW>
        end
    
        % Randomize within identifier
        expanded = expanded(randperm(numel(expanded)));
    
        idxExpandedById.(matlab.lang.makeValidName(char(id))) = expanded;
    end
    
    % Group consistency check (if grouping exists)
    if groupInfo.hasGroup
        % For each non-empty group label, ensure all identifiers within this group have equal expanded counts
        allGroups = unique(rl.group(~(rl.group=="" | ismissing(rl.group))), 'stable');
        for g = reshape(allGroups,1,[])
            if g=="" || ismissing(g), continue; end
            % ids participating this group:
            idsInG = unique(rl.identifier(rl.group==g), 'stable');
            lens = zeros(numel(idsInG),1);
            for ii = 1:numel(idsInG)
                id = idsInG(ii);
                expanded = idxExpandedById.(matlab.lang.makeValidName(char(id)));
                % count how many expanded entries belong to this group
                lens(ii) = sum(rl.group(expanded)==g);
            end
            if numel(unique(lens)) > 1
                error("Grouped stimuli require equal repeats within group '%s'. Counts=%s", char(g), mat2str(lens'));
            end
        end
    end
end

function [trialMat, meta] = buildTrialOrder_(idxExpandedById, idInfo, groupInfo)
    ids = idInfo.idsFlow;
    
    if ~groupInfo.hasGroup
        % Independent: cartesian product across identifiers (can be large!)
        lists = cell(numel(ids),1);
        for k = 1:numel(ids)
            lists{k} = idxExpandedById.(matlab.lang.makeValidName(char(ids(k))));
        end
        trialMat = cartesianProduct_(lists);
    
        % Randomize trial order
        trialMat = trialMat(randperm(size(trialMat,1)),:);
    
        meta = struct("mode","independent","ids",ids);
        return
    end
    
    % Grouped mode:
    % For each group label, build a paired list matrix [nG x nIdInG] by position (same index across ids)
    rl = rules; %#ok<NASGU> (outer)
    allGroups = unique(rules.group(~(rules.group=="" | ismissing(rules.group))), 'stable');
    
    % Build "units" = either group blocks or independent identifiers that are not grouped
    blocks = {};
    
    % Group blocks
    for g = reshape(allGroups,1,[])
        idsInG = unique(rules.identifier(rules.group==g), 'stable');
        idsInG = intersect(idsInG, ids, 'stable');
        if isempty(idsInG), continue; end
    
        % extract expanded lists restricted to this group
        subLists = cell(numel(idsInG),1);
        for k = 1:numel(idsInG)
            id = idsInG(k);
            expanded = idxExpandedById.(matlab.lang.makeValidName(char(id)));
            subLists{k} = expanded(rules.group(expanded)==g);
        end
        % pair by position (already checked equal lengths)
        nG = numel(subLists{1});
        blk = zeros(nG, numel(idsInG));
        for k = 1:numel(idsInG)
            blk(:,k) = subLists{k}(:);
        end
    
        blocks{end+1} = struct("type","group","group",g,"ids",idsInG,"mat",blk); %#ok<AGROW>
    end
    
    % Ungrouped identifiers treated as independent blocks
    for k = 1:numel(ids)
        id = ids(k);
        % if this id ever appears in any non-empty group, skip (already handled in group blocks)
        if any(rules.identifier==id & ~(rules.group=="" | ismissing(rules.group)))
            continue
        end
        expanded = idxExpandedById.(matlab.lang.makeValidName(char(id)));
        blocks{end+1} = struct("type","single","group","","ids",id,"mat",expanded(:)); %#ok<AGROW>
    end
    
    % Combine blocks by cartesian product of their rows
    trialMat = combineBlocks_(blocks, ids);
    
    % Randomize trial order
    trialMat = trialMat(randperm(size(trialMat,1)),:);
    
    meta = struct("mode","grouped","ids",ids,"blocks",{blocks});
end

function ITI = buildITI_(ev, ntrial)
    % ITI = startJitter + (tFirstEvent - 0)
    startIdx = find(ev.kind=="start",1);
    assert(~isempty(startIdx), "Start event is required.");
    
    % first non-start event onset
    tFirst = min(ev.tStart(ev.kind~="start"));
    if isempty(tFirst) || ~isfinite(tFirst)
        tFirst = 0;
    end
    
    jA = ev.jitterA(startIdx); jB = ev.jitterB(startIdx);
    if ~isfinite(jA), jA = 0; end
    if ~isfinite(jB), jB = 0; end
    lo = min(jA,jB); hi = max(jA,jB);
    
    ITI = tFirst + (lo + (hi-lo).*rand(ntrial,1));
end

function audioDB = preloadAudio_(rl, fsTarget)
    % audioDB(id) = cell array of 2xN wave matrices ready for PsychPortAudio FillBuffer
    audioDB = containers.Map('KeyType','char','ValueType','any');
    
    for i = 1:height(rl)
        id = char(rl.identifier(i));
        fp = char(rl.filePath(i));
    
        if isempty(id) || isempty(fp), continue; end
        assert(isfile(fp), "Sound file not found: %s", fp);
    
        [y, fs0] = audioread(fp);
        if size(y,2) > 2
            error("Sound channels >2 not supported: %s", fp);
        end
        if fs0 ~= fsTarget
            y = resample(y, fsTarget, fs0);
        end
    
        % Convert to 2 x N for PTB
        if size(y,2) == 1
            y2 = repmat(y(:)', 2, 1);
        else
            y2 = y'; % 2 x N
        end
    
        if ~isKey(audioDB, id)
            audioDB(id) = {y2};
        else
            audioDB(id) = [audioDB(id), {y2}];
        end
    end
end

function wave = pickWave_(audioDB, id)
id = char(string(id));
assert(isKey(audioDB, id), "No audio wave found for identifier '%s'.", id);
waves = audioDB(id);
wave = waves{randi(numel(waves))};
end

function [choiceWin, validKeycode] = parseChoiceSpec_(ev)
    choiceIdx = find(ev.kind=="choice", 1, "first");
    if isempty(choiceIdx)
        choiceWin = 0;
        validKeycode = 1:256;
        return
    end
    
    % window
    if ismember("validWindow", ev.Properties.VariableNames) && isfinite(ev.validWindow(choiceIdx)) && ev.validWindow(choiceIdx)>0
        choiceWin = double(ev.validWindow(choiceIdx));
    else
        choiceWin = double(ev.tEnd(choiceIdx) - ev.tStart(choiceIdx));
        if ~isfinite(choiceWin) || choiceWin<=0
            choiceWin = inf;
        end
    end
    
    % keys
    if ismember("validKeys", ev.Properties.VariableNames)
        validKeycode = parseValidKeys_(ev.validKeys(choiceIdx));
    else
        validKeycode = 1:256;
    end
end

function keycodes = parseValidKeys_(validKeys)
    if ismissing(validKeys) || validKeys == ""
        keycodes = 1:256;
        return;
    end
    keys = split(string(validKeys), {',',';',' '});
    keys = keys(keys~="");
    KbName('UnifyKeyNames');
    keycodes = cellfun(@KbName, cellstr(keys));
end

function sch = compileSchedule_(ev, trialRowIdxs, idInfo, rules, t0)
    % Build a schedule table for this trial with jitter + ruleRow mapping.
    %
    % We bind each (stimuli/cue) event to a specific rules row index according to identifier.
    % trialRowIdxs is a row vector with one selected rules-row per identifier in idInfo.idsFlow order.
    
    ids = idInfo.idsFlow;
    assert(numel(trialRowIdxs) == numel(ids), "Trial row length mismatch with identifiers list.");
    
    % map identifier -> rules row index
    id2row = containers.Map('KeyType','char','ValueType','double');
    for k = 1:numel(ids)
        id2row(char(ids(k))) = trialRowIdxs(k);
    end
    
    % per-event jitter
    jA = ev.jitterA; jB = ev.jitterB;
    jA(~isfinite(jA)) = 0;
    jB(~isfinite(jB)) = 0;
    lo = min(jA,jB); hi = max(jA,jB);
    jDraw = lo + (hi-lo).*rand(height(ev),1);
    
    sch = table();
    sch.evtIndex   = (1:height(ev))';
    sch.kind       = ev.kind;
    sch.modality   = ev.modality;
    sch.identifier = ev.identifier;
    
    sch.tAbs0 = t0 + (ev.tStart + jDraw);
    sch.tAbs1 = t0 + (ev.tEnd   + jDraw);
    
    % ruleRow per event
    rr = cell(height(ev),1);
    for i = 1:height(ev)
        if sch.kind(i)=="stimuli" || sch.kind(i)=="cue"
            id = string(sch.identifier(i));
            if id=="" || ismissing(id)
                rr{i} = table();
            else
                ridx = id2row(char(id));
                rr{i} = rules(ridx,:);
            end
        else
            rr{i} = table();
        end
    end
    sch.ruleRow = rr;
    
    % marker codes (simple scheme; customize as needed)
    sch.markerCode = arrayfun(@(i) markerCode_(sch.kind(i), sch.identifier(i), sch.ruleRow{i}), (1:height(sch))');
    
    % sort by onset time
    sch = sortrows(sch, "tAbs0", "ascend");

    % do not schedule start event (handled outside schedule by startSpec)
    sch = sch(sch.kind ~= "start", :);
end
    
function code = markerCode_(kind, identifier, rr)
    % Prefer rules.code for stimuli/cue; otherwise fixed base codes
    kind = string(kind);
    identifier = string(identifier);
    
    if (kind=="stimuli" || kind=="cue") && istable(rr) && ~isempty(rr) && ismember("code", rr.Properties.VariableNames)
        c = rr.code(1);
        if isnumeric(c) && isfinite(c)
            code = uint8(max(1, min(255, round(c))));
            return
        end
    end
    
    switch kind
        case "start",  base = 10;
        case "stimuli",base = 20;
        case "cue",    base = 40;
        case "choice", base = 60;
        otherwise,     base = 80;
    end
    code = uint8(base + mod(simpleHash_(char(identifier)), 50));
end

function h = simpleHash_(s)
    if isempty(s), h = 0; return; end
    x = double(s);
    h = mod(sum(x .* (1:numel(x))), 100);
end
    
function sendMarker_(triggerType_, ioObj_, address_, code_)
    try
        mTrigger(char(triggerType_), ioObj_, uint8(code_), address_);
    catch ME
        fprintf(2, "[TriggerError] %s\n", ME.message);
    end
end

function [onset, offset, code] = pickPrimaryStim_(sch)
    % For legacy behavior monitor: pick the first auditory stimuli as "primary"
    idx = find(sch.kind=="stimuli" & sch.modality=="auditory", 1, "first");
    if isempty(idx)
        onset = [];
        offset = [];
        code = [];
        return
    end
    onset = sch.tAbs0(idx);
    offset = sch.tAbs1(idx);
    
    rr = sch.ruleRow{idx};
    if istable(rr) && ~isempty(rr) && ismember("code", rr.Properties.VariableNames)
        code = rr.code(1);
    else
        code = [];
    end
end

function mon = initRealtimeMonitor_(app_, rules_)
    mon = struct("enabled",false,"processFcn",[],"processFcnName","");
    if ~ismember("processFcn", rules_.Properties.VariableNames)
        return
    end
    
    fcnStr = "";
    try
        v = rules_.processFcn(1);
        if iscell(v), v = v{1}; end
        fcnStr = string(v);
    catch
        fcnStr = "";
    end
    
    if fcnStr=="" || ismissing(fcnStr), return; end
    if ~(isprop(app_,"behavApp") && isa(app_.behavApp,"behaviorPlotApp") && isvalid(app_.behavApp))
        % You can create behaviorPlotApp here if you want; for now skip.
        return
    end
    
    try
        mon.processFcn = str2func(char(fcnStr));
        mon.processFcnName = char(fcnStr);
        mon.enabled = true;
        try, app_.behavApp.processFcn = mon.processFcn; drawnow; catch, end
    catch
        mon.enabled = false;
    end
end

function updateRealtimeMonitor_(mon_, app_, rules_, onset_, offset_, code_, push_, key_)
    if ~isstruct(mon_) || ~mon_.enabled, return; end
    if ~(isprop(app_,"behavApp") && isa(app_.behavApp,"behaviorPlotApp") && isvalid(app_.behavApp)), return; end
    try
        mon_.processFcn(app_.behavApp, rules_, onset_, offset_, code_, push_, key_);
    catch ME
        fprintf(2, "WARNING: processFcn error (%s): %s\n", mon_.processFcnName, ME.message);
    end
end

function tryPlayHint_(pID_, fsDevice_)
    % Search hint: sounds/hint/[pID].wav or [pID].mp3
    root = fileparts(mfilename("fullpath"));
    f1 = fullfile(root, "sounds", "hint", sprintf("%d.wav", pID_));
    f2 = fullfile(root, "sounds", "hint", sprintf("%d.mp3", pID_));
    if isfile(f1)
        [y, fs0] = audioread(f1);
        playAudio(y, fs0, fsDevice_);
    elseif isfile(f2)
        [y, fs0] = audioread(f2);
        playAudio(y, fs0, fsDevice_);
    end
end

function M = cartesianProduct_(lists)
    % lists: cell of vectors (each column choices)
    n = numel(lists);
    sizes = cellfun(@numel, lists);
    grids = cell(1,n);
    [grids{:}] = ndgrid(lists{:});
    M = zeros(prod(sizes), n);
    for k = 1:n
        M(:,k) = grids{k}(:);
    end
end

function trialMat = combineBlocks_(blocks, idsAll)
    % blocks: each has .ids and .mat (either vector or matrix)
    % idsAll: global identifier order (columns in trialMat)
    nIds = numel(idsAll);
    
    % Represent each block as a list of rows, each row is a full nIds vector with NaN, filled at positions
    blockRows = cell(numel(blocks),1);
    for b = 1:numel(blocks)
        blk = blocks{b};
        mat = blk.mat;
        if isvector(mat), mat = mat(:); end
        nR = size(mat,1);
    
        rowList = nan(nR, nIds);
        for k = 1:numel(blk.ids)
            id = blk.ids(k);
            col = find(idsAll==id, 1);
            rowList(:,col) = mat(:,k);
        end
        blockRows{b} = rowList;
    end
    
    % Cartesian combine blockRows
    trialMat = blockRows{1};
    for b = 2:numel(blockRows)
        A = trialMat;
        B = blockRows{b};
        outN = size(A,1) * size(B,1);
        C = nan(outN, nIds);
    
        idx = 1;
        for i = 1:size(A,1)
            for j = 1:size(B,1)
                r = A(i,:);
                s = B(j,:);
                fill = r;
                m = ~isnan(s);
                fill(m) = s(m);
                C(idx,:) = fill;
                idx = idx + 1;
            end
        end
        trialMat = C;
    end
    
    % Any remaining NaN means missing id in construction (should not happen)
    if any(isnan(trialMat), 'all')
        error("Trial order construction left NaN entries. Check identifier/group settings.");
    end
end

function startSpec = parseStartSpec_(ev)
% Parse start trigger mode and key
% Expected columns (from StartEventEditApp):
%   - triggerMode : "auto" | "keyboard"
%   - triggerKey  : key name string, e.g. "space", "return", "5%"
%
% Defaults:
%   mode = "auto"
%   key  = "space"

    startSpec = struct();
    startSpec.mode = "auto";
    startSpec.keyName = "space";
    startSpec.keycode = KbName('space');

    idx = find(ev.kind=="start", 1, "first");
    if isempty(idx)
        return
    end

    if ismember("triggerMode", ev.Properties.VariableNames)
        m = string(ev.triggerMode(idx));
        if m ~= "" && ~ismissing(m)
            startSpec.mode = validatestring(m, ["auto","keyboard"]);
            startSpec.mode = string(startSpec.mode);
        end
    end

    if startSpec.mode == "keyboard"
        if ismember("triggerKey", ev.Properties.VariableNames)
            k = string(ev.triggerKey(idx));
            if k ~= "" && ~ismissing(k)
                startSpec.keyName = k;
            end
        end
        KbName('UnifyKeyNames');
        startSpec.keycode = KbName(char(startSpec.keyName));
        if isempty(startSpec.keycode) || any(isnan(startSpec.keycode)) || startSpec.keycode<=0
            error("Invalid start triggerKey: %s", startSpec.keyName);
        end
    end
end

function vis = presentVisualSti(win_, winRect_, ruleRow_, ctx_)
%PRESENTVISUALSTI  Placeholder for visual stimulus creation/drawing.
%
% Inputs
%   win, winRect : PTB window handle and rect
%   ruleRow      : 1xN table row from rules.xlsx corresponding to ctx.identifier
%   ctx          : struct with suggested fields:
%       - identifier  : string
%       - pID         : double
%       - trialIndex  : double
%       - tPlan       : double (scheduled onset time)
%       - params      : struct (global settings)
%
% Output
%   vis : struct with suggested fields:
%       - drawFcn : function_handle, called as drawFcn(win) to draw on backbuffer
%       - meta    : struct, for logging/debugging
%
% PSEUDOCODE (do not implement now):
%   1) Validate ruleRow not empty.
%   2) Read visual parameters from ruleRow (define your columns, e.g.):
%        stimType      = ruleRow.visType        % "text"|"image"|"shape"|...
%        imagePath     = ruleRow.visImagePath   % for image
%        text          = ruleRow.visText        % for text
%        posX,posY     = ruleRow.visPosX, visPosY   % normalized [0..1] or pixels
%        sizeW,sizeH   = ruleRow.visSizeW, visSizeH
%        colorRGB      = ruleRow.visColorR/G/B or a single "R,G,B" string
%        etc.
%   3) Precompute PTB resources if needed:
%        - img = imread(imagePath)
%        - tex = Screen('MakeTexture', win, img)
%   4) Return a draw function:
%        vis.drawFcn = @(win) <Screen draw calls, DrawFormattedText, Screen('DrawTexture'), ...>
%   5) The scheduler (presentStimuli) will call:
%        vis.drawFcn(win); Screen('Flip', win, ctx.tPlan - slack);
%
% NOTE:
%   This function must NOT call Screen('Flip') itself in the intended design.

    vis = struct();
    vis.meta = struct("identifier", string(ctx_.identifier), "pID", ctx_.pID, "trialIndex", ctx_.trialIndex);
    
    % Placeholder drawFcn: do nothing
    vis.drawFcn = @(w) [];
end