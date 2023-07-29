function rulesGenerator(soundDir, ... % dir path of sound files
                        rulesPath, ... % full path of rules.xlsx
                        pID, ... % protocol ID, positive integer scalar
                        node0Hint, nodeHint, ... % shown in UI phase selection nodetree
                        apType, ... % "active" or "passive"
                        protocol, ... % protocol name, eg "TB passive1", "Offset active2"
                        ISI, ... % inter-stimuli interval in sec, positive scalar
                        varargin)
% Automatically generate rules.xlsx by sound file names.
%
% If file of rulesPath exists, its content will be reordered by pID (ascend) first 
% and the content of the same pID will be overrided.
% 
% nRepeat: scalar (for all) or vector (for single)
% cueLag: for active protocols, the time lag from the offset of prior sound to the cue for choice
% forceOpt: if set "on", will add new columns to the original table and leave blank if new params of 
%           the former ones do not exist.
%
% Recommended file name format: ord_para1Name-para1Val_para2Name-para2Val_...
%
% Notice:
% Integer, decimal and special values (inf and nan) will be exported as number and others as string.
%
% Example:
%     rulesGenerator("sounds\1\", "rules start-end.xlsx", 1, ...
%                    "start-end效应部分", "第一阶段-阈值", ...
%                    "active", ...
%                    "SE active1", ...
%                    3.5, ...
%                    40, ...
%                    0.8);

mIp = inputParser;
mIp.addOptional("nRepeat", nan, @(x) isnumeric(x) && isscalar(x));
mIp.addOptional("cueLag", nan, @(x) isnumeric(x) && isscalar(x));
mIp.addParameter("forceOpt", "off", @(x) any(validatestring(x, {'on', 'off'})));
mIp.parse(varargin{:});

nRepeat = mIp.Results.nRepeat;
cueLag = mIp.Results.cueLag;
forceOpt = mIp.Results.forceOpt;

files = dir(soundDir);
[~, soundNames] = cellfun(@(x) fileparts(x), {files.name}, "UniformOutput", false);
soundNames = soundNames(3:end)';

% Parse parameters from sound names
temp = cellfun(@(x) split(x, '_'), soundNames, "UniformOutput", false);
temp = cellfun(@(x) x(2:end), temp, "UniformOutput", false);
temp = cellfun(@(x) cellfun(@(y) split(y, '-'), x, "UniformOutput", false), temp, "UniformOutput", false);

paraNames = cellfun(@(x) x{1}, temp{1}, "UniformOutput", false);

temp = cellfun(@(x) cellfun(@(y) string(y{2}), x), temp, "UniformOutput", false);
paraVals = num2cell([temp{:}]', 1)';
numIdx = cellfun(@(x) all(arrayfun(@(y) all(isstrprop(strrep(y, '.', ''), "digit") | all(isstrprop(y, "digit")) | strcmpi(y, 'nan') | strcmpi(y, 'inf')), x)), paraVals);
paraVals(numIdx) = cellfun(@(x) str2double(x), paraVals(numIdx), "UniformOutput", false);
paraVals = cellfun(@(x) mat2cell(x, ones(length(x), 1)), paraVals, "UniformOutput", false);

n = length(soundNames);

if isscalar(nRepeat)
    nRepeat = {repmat({nRepeat}, [n, 1])};
else
    nRepeat = mat2cell(reshape(nRepeat, [length(nRepeat), 1]), ones(n, 1));
end

paraNames = [{'pID'}; ...
             {'node0Hint'}; ...
             {'nodeHint'}; ...
             {'apType'}; ...
             {'protocol'}; ...
             {'code'}; ...
             {'ISI'}; ...
             {'nRepeat'}; ...
             {'cueLag'}; ...
             paraNames];
paraVals = [{repmat({pID},       [n, 1])}; ...
            {repmat({node0Hint}, [n, 1])}; ...
            {repmat({nodeHint},  [n, 1])}; ...
            {repmat({apType},    [n, 1])}; ...
            {repmat({protocol},  [n, 1])}; ...
            {mat2cell((4:3 + n)', ones(n, 1))}; ...
            {repmat({ISI},       [n, 1])}; ...
            nRepeat;
            cueLag;
            paraVals];

tb2Insert = reshape([paraNames, paraVals]', [], 1);
tb2Insert = struct2table(struct(tb2Insert{:}));

[pathstr, name, ext] = fileparts(rulesPath);
if exist(rulesPath, "file")
    tb0 = readtable(rulesPath);

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
            Msgbox({ME.message; ''; '已另存为尾缀为_pID-x.xlsx文件'}, "Warning", "Alignment", "top-center");

            % Merge to former rules file (merge common parameters only)
            writetable([tb0(:, 1:9); tb2Insert(:, 1:9)], rulesPath);
            % Create new rules file for a specific protocol
            writetable(tb2Insert, fullfile(pathstr, strcat(name, "_pID-", num2str(pID), ext)));
        else
            tbNew = [tb0(1:insertIdx, 1:9); tb2Insert(:, 1:9); tb0(insertIdx + 1:end, 1:9)];
            paraNames = unqiue([paraNames; tb0.Properties.VariableNames(10:end)'], "stable");

            for pIndex = 10:length(paraNames)
                
                if ~contains(paraNames{pIndex}, tb2Insert.Properties.VariableNames)
                    tbNew.(paraNames{pIndex}) = [tb0(1:insertIdx, :).(paraNames{pIndex}); nan(size(tb2Insert, 1), 1); tb0(insertIdx + 1:end, :).(paraNames{pIndex})];
                elseif contains(paraNames{pIndex}, tb0.Properties.VariableNames)
                    tbNew.(paraNames{pIndex}) = [tb0(1:insertIdx, :).(paraNames{pIndex}); tb2Insert.(paraNames{pIndex}); tb0(insertIdx + 1:end, :).(paraNames{pIndex})];
                else
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