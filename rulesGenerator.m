function rulesGenerator(soundDir, rulesPath, pID, node0Tag, nodeTag, node0Hint, nodeHint, apType, protocol, ISI, nRepeat)
    % For filename = ord_para1Name-para1Val_para2Name-para2Val_...
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
    temp = cellfun(@(x) split(x, '_'), soundNames, "UniformOutput", false);
    temp = cellfun(@(x) x(2:end), temp, "UniformOutput", false);
    temp = cellfun(@(x) cellfun(@(y) split(y, '-'), x, "UniformOutput", false), temp, "UniformOutput", false);
    paraNames = cellfun(@(x) x{1}, temp{1}, "UniformOutput", false);
    paraVals = changeCellRowNum(cellfun(@(x) cellfun(@(y) replaceVal(str2double(y{2}), nan, inf), x), temp, "UniformOutput", false));
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
    paraVals = [{repmat({pID}, [n, 1])}; ...
                {repmat({node0Tag}, [n, 1])}; ...
                {repmat({nodeTag}, [n, 1])}; ...
                {repmat({node0Hint}, [n, 1])}; ...
                {repmat({nodeHint}, [n, 1])}; ...
                {repmat({apType}, [n, 1])}; ...
                {repmat({protocol}, [n, 1])}; ...
                {mat2cell((4:3 + n)', ones(n, 1))}; ...
                paraVals; ...
                {repmat({ISI}, [n, 1])}; ...
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