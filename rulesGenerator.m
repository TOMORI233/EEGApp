function rulesGenerator(soundDir, ...            % directory path of sound files
                        rulesPath, ...           % full path of rules.xlsx
                        pID, ...                 % protocol ID, positive integer scalar
                        node0Hint, nodeHint, ... % texts shown in UI phase selection nodetree
                                             ... % usually, [node0Hint] -> project/protocol name
                                             ... %          [nodeHint ] -> protocol/phase name
                        apType, ...              % task type, "active" or "passive"
                        protocol, ...            % protocol name, eg "TB passive1", "Offset active2"
                        opts)
% Description:
%     Automatically generate rules.xlsx by sound file names.
%
% Notice:
%     - If file of rulesPath exists, its content will be reordered by pID (ascend) first and the content 
%       of the same pID will be overrided.
%     - Integer, decimal and special values (inf and nan) will be exported as number and others as string.
%     - Recommended file name format: ord_para1Name-para1Val_para2Name-para2Val_...
%     - DO NOT put duplicated parameters in your wave file name (eg. protocol, ITI).
%
% Optional Input:
%     nRepeat: scalar (for all) or vector (for single).
%     processFcn: function_handle, for behavior real-time monitoring.
%                 Please do make sure ITI > soundDur + choiceWin + ~0.5 to avoid delay in playing sounds.
%     forceOpt: if set "on", will add new columns to the original table and leave blank if new params of 
%               the former ones do not exist.
%     eventFlow: full path of a MAT file which defines the event flow of the task, including ITI,
%                stimulus duration, cue, and choice window.
%     identifier: identifier of stimuli (e.g., 'A1', 'cue') in the event flow.
%
% Example:
%     % Create event flow for this protocol. Use eventFlowApp
%     app = eventFlowApp();
%     uiwait(app.UIFigure);
%     eventFlow = app.filepath;
%     
%     % Generate rule file
%     pID = 101;
%     nRepeat = 2;
%     rulesGenerator(fullfile("sounds", num2str(pID)),    ... sound file path
%                    "rules\start-end effect\rules.xlsx", ... rule file path
%                    pID,                                 ... protocol ID
%                    "Start-End Effect",                  ... project name
%                    "Phase 0 - pre",                     ... phase name
%                    "active",                            ... task type
%                    "SE pre",                            ... protocol name
%                    "nRepeat", nRepeat,                  ... repeat times of trials
%                    "eventFlow", eventFlow,              ... event flow path
%                    "forceOpt", "on");

%% Parse inputs
arguments
    soundDir    {mustBeFolder, mustBeTextScalar}
    rulesPath   {mustBeTextScalar}
    pID         (1,1) double {mustBePositive, mustBeInteger}
    node0Hint   {mustBeTextScalar}
    nodeHint    {mustBeTextScalar}
    apType      {mustBeTextScalar}
    protocol    {mustBeTextScalar}

    opts.nRepeat    (:,1) double = []
    opts.processFcn (1,1) function_handle
    opts.forceOpt   {mu.OptionState.validate} = mu.OptionState.Off
    opts.eventFlow  {mustBeFile, mustBeTextScalar} = fullfile(fileparts(mfilename("fullpath")), "config", sprintf('preset_%s.mat', apType));
    opts.identifier = '';
end

% sound files
files = dir(fullfile(soundDir, "*.wav"));
assert(~isempty(files), "Empty or non-existent directory of sounds!");
[~, soundNames] = cellfun(@(x) fileparts(x), {files.name}, "UniformOutput", false);
n = length(soundNames);

% identifier in the event flow
identifier = cellstr(opts.identifier);
if isscalar(identifier)
    identifier = {repmat(identifier, [n, 1])};
else
    assert(numel(identifier) == n, "The number of identifiers should match the number of sound files");
    identifier = {identifier};
end

% task type
apType = validatestring(apType, {'passive', 'active'});

% repeat times
nRepeat = opts.nRepeat;
if isempty(nRepeat)
    nRepeat = {repmat({nan}, [n, 1])};
elseif isscalar(nRepeat)
    nRepeat = {repmat({nRepeat}, [n, 1])};
else % numeric vector
    assert(numel(nRepeat) == n, "The number of nRepeat should match the number of sound files");
    nRepeat = {num2cell(nRepeat(:))};
end

% process function handle, for real-time monitoring
if isfield(opts, "processFcn")
    processFcn = opts.processFcn;
    processFcn = {repmat({string(func2str(processFcn))}, [n, 1])};
else
    processFcn = {repmat({""}, [n, 1])};
end

% force append xlsx file option (concatenate anyway)
forceOpt = mu.OptionState.create(opts.forceOpt).toLogical;

% event flow table path
eventFlow = opts.eventFlow;
eventFlow = {repmat({string(eventFlow)}, [n, 1])};

%% Parse parameters from sound names
temp = cellfun(@(x) split(x, '_'), soundNames, "UniformOutput", false);
temp = cellfun(@(x) x(2:end), temp, "UniformOutput", false);
paraList = cellfun(@(x) cellfun(@(y) split(y, '-'), x, "UniformOutput", false), temp, "UniformOutput", false);

paraStruct = cell(length(paraList), 1);
for index = 1:length(paraList)
    temp = [cellfun(@(x) x{1}, paraList{index}, "UniformOutput", false), ...
            cellfun(@(x) x{2}, paraList{index}, "UniformOutput", false)]';
    paraStruct{index} = struct(temp{:});
end
paraStruct = mu.structcat(paraStruct{:});
paraNames = fieldnames(paraStruct);

% convert numeric params to double
for index = 1:length(paraNames)
    temp = {paraStruct.(paraNames{index})}';
    if all(cellfun(@(x) all(isstrprop(strrep(x, '.', ''), "digit") | all(isstrprop(x, "digit")) | strcmpi(x, 'nan') | strcmpi(x, 'inf')), ...
                   temp(~cellfun(@isempty, temp))))
        paraStruct = mu.addfield(paraStruct, paraNames{index}, cellfun(@str2double, temp));
    end
end

paraVals = cellfun(@(x) {paraStruct.(x)}', paraNames, "UniformOutput", false);

%% Write to xlsx
presetParams = [{'pID'}; ...
                {'node0Hint'}; ...
                {'nodeHint'}; ...
                {'apType'}; ...
                {'protocol'}; ...
                {'code'}; ...
                {'identifier'}
                {'eventFlow'}; ...
                {'nRepeat'}; ...
                {'processFcn'}];
paraNames = [presetParams; paraNames];
paraVals = [{repmat({pID},        [n, 1])}; ...
            {repmat({node0Hint},  [n, 1])}; ...
            {repmat({nodeHint},   [n, 1])}; ...
            {repmat({apType},     [n, 1])}; ...
            {repmat({protocol},   [n, 1])}; ...
            {num2cell((4:3 + n)')}; ...
            identifier; ...
            eventFlow; ...
            nRepeat;
            processFcn;
            paraVals];

tb2Insert = reshape([paraNames, paraVals]', [], 1);
tb2Insert = struct2table(struct(tb2Insert{:}));

[pathstr, name, ext] = fileparts(rulesPath);
if strcmp(pathstr, '')
    pathstr = pwd;
end

if exist(fullfile(pathstr, strcat(name, ext)), "file")
    tb0 = readtable(fullfile(pathstr, strcat(name, ext)));

    % Reorder by pID
    [~, idx] = sortrows(tb0.pID, 1, "ascend");
    tb0 = tb0(idx, :);

    % Override the old
    tb0(tb0.pID == pID, :) = [];

    insertIdx = find(tb0.pID > pID, 1) - 1;
    if isempty(insertIdx)
        insertIdx = size(tb0, 1);
    end

    try
        writetable([tb0(1:insertIdx, :); tb2Insert; tb0(insertIdx + 1:end, :)], rulesPath, "WriteMode", "replacefile");
    catch ME

        if strcmpi(forceOpt, "off")
            uialert({ME.message; ''; '已另存为尾缀为_pID-x.xlsx文件'});

            % Merge to former rules file (merge common parameters only)
            writetable([tb0(:, 1:numel(presetParams)); tb2Insert(:, 1:numel(presetParams))], rulesPath);

            % Create new rules file for a specific protocol
            writetable(tb2Insert, fullfile(pathstr, strcat(name, "_pID-", num2str(pID), ext)), "WriteMode", "replacefile");
        else
            tbNew = [tb0(1:insertIdx, 1:numel(presetParams)); tb2Insert(:, 1:numel(presetParams)); tb0(insertIdx + 1:end, 1:numel(presetParams))];
            paraNames = unique([paraNames; tb0.Properties.VariableNames(numel(presetParams):end)'], "stable");

            for pIndex = numel(presetParams):length(paraNames)
                
                if ~any(strcmp(paraNames{pIndex}, tb2Insert.Properties.VariableNames))
                    % Parameter exists in old rules but not in new rules
                    tbNew.(paraNames{pIndex}) = [tb0(1:insertIdx, :).(paraNames{pIndex}); nan(size(tb2Insert, 1), 1); tb0(insertIdx + 1:end, :).(paraNames{pIndex})];
                elseif any(strcmp(paraNames{pIndex}, tb0.Properties.VariableNames))
                    % Parameter exists in both old and new rules
                    tbNew.(paraNames{pIndex}) = [tb0(1:insertIdx, :).(paraNames{pIndex}); tb2Insert.(paraNames{pIndex}); tb0(insertIdx + 1:end, :).(paraNames{pIndex})];
                else
                    % Parameter exists in new rules but not in old rules
                    tbNew.(paraNames{pIndex}) = [nan(insertIdx, 1); tb2Insert.(paraNames{pIndex}); nan(size(tb0, 1) - insertIdx, 1)];
                end

            end

            writetable(tbNew, rulesPath, "WriteMode", "replacefile");
        end

    end

else
    % Create new rules file
    writetable(tb2Insert, rulesPath);
end

return;
end