function rulesGenerator(soundDir, rulesPath, pID, node0Hint, nodeHint, protocol, opts)
%RULESGENERATOR  Automatically generate/update rules.xlsx by sound file names.
%
% Filename convention (recommended):
%   ord_param1Name-param1Val_param2Name-param2Val_...
%   e.g., 001_ISI-500_ratio-1.06_group-A.wav
%
% Behavior:
%   - If rulesPath exists, reorder by pID ascending, remove old rows with same pID, then insert new block.
%   - Numeric-like params (incl. NaN/Inf, scientific notation) are converted to double; others stay as string.
%   - forceOpt=On will union columns between old/new; missing values are filled with NaN/"" accordingly.
%
% Example:
%   % Create event flow for this protocol. Use eventFlowApp
%   app = eventFlowApp();
%   uiwait(app.UIFigure);
%   eventFlow = app.filepath;
%   delete(app);
%   
%   % Generate rule file
%   pID = 101;
%   nRepeat = 2;
%   rulesGenerator(fullfile("sounds", num2str(pID)),    ... sound file path
%                  "rules\start-end effect\rules.xlsx", ... rule file path
%                  pID,                                 ... protocol ID
%                  "Start-End Effect",                  ... project name
%                  "Phase 0 - pre",                     ... phase name
%                  "SE pre",                            ... protocol name
%                  "nRepeat", nRepeat,                  ... repeat times of trials
%                  "eventFlow", eventFlow,              ... event flow path
%                  "identifier", "A1",                  ... identifer matched to event flow
%                  "forceOpt", "on");

%% Parse inputs
arguments
    soundDir  (1,1) string {mustBeFolder}
    rulesPath (1,1) string
    pID       (1,1) double {mustBePositive, mustBeInteger}
    node0Hint (1,1) string
    nodeHint  (1,1) string
    protocol  (1,1) string

    opts.nRepeat    (:,1) double = []
    opts.processFcn = []
    opts.forceOpt   {mu.OptionState.validate} = mu.OptionState.Off
    opts.eventFlow  (1,1) string = ""   % leave empty by default; user should pass it if needed
    opts.identifier = ""
    opts.group      = ""
end

forceOpt = mu.OptionState.create(opts.forceOpt).toLogical;

%% Collect sound files
files = dir(fullfile(soundDir, "*.wav"));
assert(~isempty(files), "Empty or non-existent directory of sounds: %s", soundDir);

n = numel(files);
soundPaths = string(fullfile({files.folder}, {files.name}))';
soundNames = string(erase({files.name}, ".wav"))'; % base names

%% Expand per-file meta fields
identifier = expandToN(opts.identifier, n, "identifier");
group      = expandToN(opts.group,      n, "group");
eventFlow  = expandToN(opts.eventFlow,  n, "eventFlow");

nRepeat = opts.nRepeat;
if isempty(nRepeat)
    nRepeatCol = repmat({nan}, n, 1);
elseif isscalar(nRepeat)
    nRepeatCol = repmat({nRepeat}, n, 1);
else
    assert(numel(nRepeat) == n, "nRepeat must be scalar or length == number of files (%d).", n);
    nRepeatCol = num2cell(nRepeat(:));
end

if isempty(opts.processFcn)
    processFcnCol = repmat({""}, n, 1);
else
    processFcnCol = repmat({string(func2str(opts.processFcn))}, n, 1);
end

%% Parse parameters from sound names
% Split by "_" and skip the first token (ord).
% Each remaining token should be "name-value".
paramPerFile = arrayfun(@oneName2struct, soundNames, "UniformOutput", false);

% Union all parameter names (struct -> fieldnames)
allKeys = {};
for i = 1:n
    k = fieldnames(paramPerFile{i});
    allKeys = [allKeys; k(:)]; %#ok<AGROW>
end
allKeys = unique(string(allKeys), "stable");

% Build parameter table (as string initially)
paramTb = table();
for k = 1:numel(allKeys)
    key  = allKeys(k);
    keyc = char(key);  % struct fieldname must be char

    col = strings(n,1);
    for i = 1:n
        S = paramPerFile{i};
        if isfield(S, keyc)
            col(i) = string(S.(keyc));
        else
            col(i) = "";
        end
    end

    % keyc is already madeValidName in version C, but keep it safe
    paramTb.(matlab.lang.makeValidName(keyc)) = col;
end

% Convert numeric-like columns to double
paramTb = convertNumericLikeColumns(paramTb);

%% Compose table to insert
presetTb = table();
presetTb.pID        = repmat(pID, n, 1);
presetTb.node0Hint  = repmat(node0Hint, n, 1);
presetTb.nodeHint   = repmat(nodeHint, n, 1);
presetTb.protocol   = repmat(protocol, n, 1);
presetTb.code       = (4:(3+n))';
presetTb.identifier = identifier;
presetTb.group      = group;
presetTb.eventFlow  = eventFlow;
presetTb.nRepeat    = nRepeatCol;
presetTb.processFcn = processFcnCol;
presetTb.filePath   = cellstr(soundPaths); % keep as cellstr for Excel friendliness

tb2Insert = [presetTb, paramTb];

%% Ensure rulesPath folder
rulesPath = mu.getabspath(rulesPath);
rulesFolder = fileparts(rulesPath);
if ~exist(rulesFolder, "dir")
    mkdir(rulesFolder);
end

%% Write / merge with existing
if exist(rulesPath, "file")
    tb0 = readtable(rulesPath, "TextType", "string");
    tbMerged = mergeRulesTable(tb0, tb2Insert, pID, forceOpt);
    writetable(tbMerged, rulesPath, "WriteMode", "replacefile");
else
    writetable(tb2Insert, rulesPath);
end

end

%% -------- helpers --------

function col = expandToN(x, n, name)
    % Expand scalar text to n×1 string, or validate vector length.
    if ismissing(x) || (isstring(x) && strlength(x)==0)
        col = repmat("", n, 1);
        return;
    end
    
    x = string(x);
    if isscalar(x)
        col = repmat(x, n, 1);
    else
        assert(numel(x) == n, "The number of %s should match the number of sound files (%d).", name, n);
        col = x(:);
    end
end

function S = oneName2struct(name)
    toks = split(name,"_"); toks = toks(2:end);
    toks = toks(strlength(toks)>0);

    S = struct();
    for tok = toks(:).'
        parts = split(tok,"-");
        if numel(parts) < 2, continue; end
        key = matlab.lang.makeValidName(parts(1));
        S.(key) = join(parts(2:end), "-");
    end
end

function tb = convertNumericLikeColumns(tb)
    % Convert columns that look like numbers (incl. NaN/Inf, scientific notation) to double.
    vars = tb.Properties.VariableNames;
    for i = 1:numel(vars)
        v = tb.(vars{i});
        if ~isstring(v)
            continue;
        end
        vv = strip(v);
        nonEmpty = vv(strlength(vv)>0);
    
        if isempty(nonEmpty)
            continue;
        end
    
        % Try numeric conversion; accept if ALL non-empty parse to number or NaN/Inf string.
        d = str2double(nonEmpty);
        ok = ~isnan(d) | ismember(lower(nonEmpty), ["nan","inf","+inf","-inf"]);
        if all(ok)
            out = nan(height(tb),1);
            dAll = str2double(vv);
            out(strlength(vv)>0) = dAll(strlength(vv)>0);
            % Handle Inf strings explicitly (str2double already does Inf/-Inf; keep for clarity)
            tb.(vars{i}) = out;
        end
    end
end

function tbNew = mergeRulesTable(tb0, tbIns, pID, forceOpt)
    % Reorder by pID asc, remove old pID rows, insert new block before first pID > target.
    assert(any(strcmp(tb0.Properties.VariableNames, "pID")), "Existing rules file must contain column 'pID'.");
    
    % Sort
    tb0 = sortrows(tb0, "pID", "ascend");
    
    % Remove old pID block
    tb0(tb0.pID == pID, :) = [];
    
    % Find insert position
    idx = find(tb0.pID > pID, 1, "first");
    if isempty(idx)
        insertBefore = height(tb0) + 1;
    else
        insertBefore = idx; % can be 1 (insert at head)
    end
    
    if ~forceOpt
        % Keep only intersection of columns (preserve tbIns order)
        common = intersect(tb0.Properties.VariableNames, tbIns.Properties.VariableNames, "stable");
        tb0c = tb0(:, common);
        tbIc = tbIns(:, common);
    
        tbNew = [tb0c(1:insertBefore-1, :); tbIc; tb0c(insertBefore:end, :)];
        return;
    end
    
    % forceOpt: union columns, fill missing appropriately
    allVars = unique([tb0.Properties.VariableNames, tbIns.Properties.VariableNames], "stable");
    
    tb0u = addMissingVars(tb0,  allVars);
    tbIu = addMissingVars(tbIns, allVars);
    
    tbNew = [tb0u(1:insertBefore-1, :); tbIu; tb0u(insertBefore:end, :)];
    end
    
    function tb = addMissingVars(tb, allVars)
    for i = 1:numel(allVars)
        vn = allVars{i};
        if ~any(strcmp(tb.Properties.VariableNames, vn))
            % Decide default filler based on "stringy" guess: use "" for text-ish, NaN for numeric-ish is hard.
            % We choose "" (string) then Excel-friendly; but keep NaN if table seems numeric-only later.
            tb.(vn) = repmat(missing, height(tb), 1);
        end
    end
    tb = tb(:, allVars);
end
