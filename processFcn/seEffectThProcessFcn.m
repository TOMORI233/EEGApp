function seEffectThProcessFcn(app, rules, trialsData)
    % Clear axes
    cla(app.ax);

    % Behavior process
    controlCode = rules.code(isnan(rules.deltaAmp)); % rules index of control group
    trialAll = mu_preprocess_generalProcessFcn(trialsData, rules);

    if isempty(trialAll)
        return;
    end

    choice = mu_unwrapTrialEvents(trialAll, "type", "choice");
    trialAll = mu_unwrapTrialEvents(trialAll, "type", "stimuli");

    correct = (ismember([trialAll.code]', controlCode(:)) & [choice.key]' == 39) | ...
              (~ismember([trialAll.code]', controlCode(:)) & [choice.key]' == 37);
    trialAll = mu.addfield(trialAll, "correct", correct);
    miss = [choice.key]' == 0;
    trialAll = mu.addfield(trialAll, "miss", miss);

    nMiss = sum([trialAll.miss]);
    nTotal = numel(trialAll);
    trialAll([trialAll.miss]) = [];
    
    % Plot behavior
    trialsControl = trialAll(isnan([trialAll.pos]));
    trialsMid = trialAll([trialAll.pos] == 50);
    trialsHead = trialAll([trialAll.pos] < 50);
    trialsTail = trialAll([trialAll.pos] > 50);
    
    deltaAmp = unique([trialAll.deltaAmp]);
    deltaAmp(isnan(deltaAmp)) = [];
    ratioMid = zeros(1, length(deltaAmp));
    ratioHead = zeros(1, length(deltaAmp));
    ratioTail = zeros(1, length(deltaAmp));
    ratioAll = zeros(1, length(deltaAmp));
    for dIndex = 1:length(deltaAmp)
        temp = trialsMid([trialsMid.deltaAmp] == deltaAmp(dIndex));
        ratioMid(dIndex) = sum([temp.correct]) / length(temp);
    
        temp = trialsHead([trialsHead.deltaAmp] == deltaAmp(dIndex));
        ratioHead(dIndex) = sum([temp.correct]) / length(temp);
    
        temp = trialsTail([trialsTail.deltaAmp] == deltaAmp(dIndex));
        ratioTail(dIndex) = sum([temp.correct]) / length(temp);
    
        temp = trialAll([trialAll.deltaAmp] == deltaAmp(dIndex));
        ratioAll(dIndex) = sum([temp.correct]) / length(temp);
    end
    deltaAmp = [0, deltaAmp];
    ratioControl = 1 - sum([trialsControl.correct]) / length(trialsControl);
    ratioMid =  [ratioControl, ratioMid];
    ratioHead = [ratioControl, ratioHead];
    ratioTail = [ratioControl, ratioTail];

    plot(app.ax, deltaAmp, ratioMid, 'r.-', 'LineWidth', 2, "MarkerSize", 15, 'DisplayName', 'Middle');
    set(app.ax, 'FontSize', 14);
    hold(app.ax, "on");
    plot(app.ax, deltaAmp, ratioHead, 'b.-', 'LineWidth', 2, "MarkerSize", 15, 'DisplayName', 'Head');
    plot(app.ax, deltaAmp, ratioTail, 'k.-', 'LineWidth', 2, "MarkerSize", 15, 'DisplayName', 'Tail');
    legend(app.ax, "Location", "best");
    title(app.ax, ...
          ['Total: ', num2str(nTotal), ' | ', ...
           'Miss: ', num2str(nMiss)]);
    xlabel(app.ax, 'Difference in amplitude');
    ylabel(app.ax, 'Push for difference ratio');
    set(app.ax, "XLimitMethod", "tight");
    ylim(app.ax, [0, 1]);
    drawnow;
end