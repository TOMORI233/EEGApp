function seEffectLocProcessFcn(app, rules, onset, offset, code, push, key)
    % Delete empty trial
    nTotal0 = length(onset);
    trialsData = struct('onset',  onset, ...
                        'offset', offset, ...
                        'code',   code, ...
                        'push',   push, ...
                        'key',    key);
    trialsData(cellfun(@isempty, onset)) = [];

    % Clear axes
    cla(app.ratioAxes);

    % Behavior process
    controlIdx = find(isnan(rules.deltaAmp)); % rules index of control group
    trialAll = generalProcessFcn(trialsData, rules, controlIdx);

    if isempty(trialAll)
        return;
    end
    
    nMiss = sum([trialAll.miss]);
    nTotal = length(trialAll);
    trialAll([trialAll.miss]) = [];
    
    % Plot behavior
    pos = unique([trialAll.pos]);
    pos(isnan(pos)) = [];

    trialsControl = trialAll(isnan([trialAll.pos]));
    
    ratio = zeros(1, length(pos));
    for lIndex = 1:length(pos)
        temp = trialAll([trialAll.pos] == pos(lIndex));
        ratio(lIndex) = sum([temp.correct]) / length(temp);
    end
    
    plot(app.ratioAxes, pos, ratio, "k.-", "LineWidth", 2, "MarkerSize", 20);
    set(app.ratioAxes, 'FontSize', 14);
    xlabel(app.ratioAxes, 'Normalized change position in percentage (%)');
    ylabel(app.ratioAxes, 'Push for difference ratio');
    ylim(app.ratioAxes, [0, 1]);
    xlim(app.ratioAxes, [0, 100]);
    title(app.ratioAxes, ...
          ['Total: ', num2str(nTotal), '/', num2str(nTotal0), ' | ', ...
           'Miss: ', num2str(nMiss), ' | ', ...
           'Control: ', num2str(sum([trialsControl.correct])), '/', num2str(length(trialsControl))]);
    drawnow;
end