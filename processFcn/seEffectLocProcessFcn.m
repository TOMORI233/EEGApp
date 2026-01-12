function seEffectLocProcessFcn(app, rules, trialsData)
    % Clear axes
    cla(app.ax);

    % Behavior process
    controlCode = rules.code(isnan(rules.deltaAmp)); % rules index of control group
    trialAll = mu_preprocess_generalProcessFcn(trialsData, rules);

    if isempty(trialAll)
        return;
    end

    stimuli = mu_unwrapTrialEvents(trialAll, "type", "stimuli");
    choice = mu_unwrapTrialEvents(trialAll, "type", "choice");

    correct = (ismember([stimuli.code]', controlCode(:)) & [choice.key]' == 39) | ...
              (~ismember([stimuli.code]', controlCode(:)) & [choice.key]' == 37);
    trialAll = mu.addfield(trialAll, "correct", correct);
    miss = [choice.key]' == 0;
    trialAll = mu.addfield(trialAll, "miss", miss);

    nMiss = sum([trialAll.miss]);
    nTotal = numel(trialAll);
    trialAll([trialAll.miss]) = [];
    
    % Plot behavior
    pos = unique([stimuli.pos]);
    pos(isnan(pos)) = [];

    trialsControl = trialAll(isnan([stimuli.pos]));
    
    ratio = zeros(1, length(pos));
    for lIndex = 1:length(pos)
        temp = trialAll([trialAll.pos] == pos(lIndex));
        ratio(lIndex) = sum([temp.correct]) / length(temp);
    end
    
    plot(app.ax, pos, ratio, "k.-", "LineWidth", 2, "MarkerSize", 20);
    set(app.ax, 'FontSize', 14);
    xlabel(app.ax, 'Normalized change position in percentage (%)');
    ylabel(app.ax, 'Push for difference ratio');
    ylim(app.ax, [0, 1]);
    xlim(app.ax, [0, 100]);
    title(app.ax, ...
          ['Total: ', num2str(nTotal), ' | ', ...
           'Miss: ', num2str(nMiss), ' | ', ...
           'Control: ', num2str(sum([trialsControl.correct])), '/', num2str(length(trialsControl))]);
    drawnow;
end