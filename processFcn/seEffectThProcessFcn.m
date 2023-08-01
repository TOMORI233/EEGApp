function seEffectThProcessFcn(app, rules, onset, offset, code, push, key)
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
    
    % plot behavior
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

    plot(app.ratioAxes, deltaAmp, ratioMid, 'r.-', 'LineWidth', 2, "MarkerSize", 15, 'DisplayName', 'Middle');
    set(app.ratioAxes, 'FontSize', 14);
    hold(app.ratioAxes, "on");
    plot(app.ratioAxes, deltaAmp, ratioHead, 'b.-', 'LineWidth', 2, "MarkerSize", 15, 'DisplayName', 'Head');
    plot(app.ratioAxes, deltaAmp, ratioTail, 'k.-', 'LineWidth', 2, "MarkerSize", 15, 'DisplayName', 'Tail');
    legend(app.ratioAxes, "Location", "best");
    title(app.ratioAxes, ...
          ['Total: ', num2str(nTotal), '/', num2str(nTotal0), ' | ', ...
           'Miss: ', num2str(nMiss)]);
    xlabel(app.ratioAxes, 'Difference in amplitude');
    ylabel(app.ratioAxes, 'Push for difference ratio');
    set(app.ratioAxes, "XLimitMethod", "tight");
    ylim(app.ratioAxes, [0, 1]);
    drawnow;
end