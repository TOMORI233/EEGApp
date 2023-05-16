function rulesGenerator(soundDir, rulesPath, pID, ...
                        node0Tag, nodeTag, ... % nodetree tag (should be unique)
                        node0Hint, nodeHint, ... % shown in UI phase selection nodetree
                        apType, ... % "active" or "passive"
                        protocol, ... % protocol name, eg "TB passive1", "Offset active2"
                        ISI, ...
                        nRepeat) % scalar (for all) or vector (for single)
    % Automatically generate rules.xlsx by sound file names.
    %
    % If file of rulesPath exists, results will be added to the following rows
    % with the former content reserved.
    %
    % Recommended file name format: ord_para1Name-para1Val_para2Name-para2Val_...
    %
    % Notice:
    % Integer will be exported as number and others as string.
    % Decimal is not recommended, which will be exported as string.
    %
    % Example:
    %     rulesGenerator("sounds\1\", "rules start-end.xlsx", 1, ...
    %                    "SESectionNode", "SEPhase1Node", ...
    %                    "start-end效应部分", "第一阶段-阈值", ...
    %                    "active", ...
    %                    "SE active1", ...
    %                    3.5, ...
    %                    40);

    narginchk(3, 11);

    if nargin < 4  || isempty(node0Tag ), node0Tag  = nan; end
    if nargin < 5  || isempty(nodeTag  ), nodeTag   = nan; end
    if nargin < 6  || isempty(node0Hint), node0Hint = nan; end
    if nargin < 7  || isempty(nodeHint ), nodeHint  = nan; end
    if nargin < 8  || isempty(apType   ), apType    = nan; end
    if nargin < 9  || isempty(protocol ), protocol  = nan; end
    if nargin < 10 || isempty(ISI      ), ISI       = nan; end
    if nargin < 11 || isempty(nRepeat  ), nRepeat   = nan; end

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
    numIdx = cellfun(@(x) all(arrayfun(@(y) all(isstrprop(y, "digit") | strcmpi(y, 'nan') | strcmpi(y, 'inf')), x)), paraVals);
    paraVals(numIdx) = cellfun(@(x) str2double(x), paraVals(numIdx), "UniformOutput", false);
    paraVals = cellfun(@(x) mat2cell(x, ones(length(x), 1)), paraVals, "UniformOutput", false);

    n = length(soundNames);

    if isscalar(nRepeat)
        nRepeat = {repmat({nRepeat}, [n, 1])};
    else
        nRepeat = mat2cell(reshape(nRepeat, [length(nRepeat), 1]), ones(n, 1));
    end

    paraNames = [{'pID'}; ...
                 {'node0Tag'}; ...
                 {'nodeTag'}; ...
                 {'node0Hint'}; ...
                 {'nodeHint'}; ...
                 {'apType'}; ...
                 {'protocol'}; ...
                 {'code'}; ...
                 paraNames; ...
                 {'ISI'}; ...
                 {'nRepeat'}];
    paraVals = [{repmat({pID},       [n, 1])}; ...
                {repmat({node0Tag},  [n, 1])}; ...
                {repmat({nodeTag},   [n, 1])}; ...
                {repmat({node0Hint}, [n, 1])}; ...
                {repmat({nodeHint},  [n, 1])}; ...
                {repmat({apType},    [n, 1])}; ...
                {repmat({protocol},  [n, 1])}; ...
                {mat2cell((4:3 + n)', ones(n, 1))}; ...
                paraVals; ...
                {repmat({ISI},       [n, 1])}; ...
                nRepeat];

    params = reshape([paraNames, paraVals]', [], 1);
    params = struct2table(struct(params{:}));

    try
        tb = [readtable(rulesPath); params];
    catch
        tb = params;
    end

    writetable(tb, rulesPath);
    return;
end