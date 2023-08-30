function trialAll = generalProcessFcn(trialsData, rules, controlIdx)

    if isempty(trialsData)
        trialAll = [];
    end

    for tIndex = 1:length(trialsData)
        trialAll(tIndex, 1).trialNum = tIndex;
    
        idx = find(rules.code == trialsData(tIndex).code);
    
        for vIndex = 1:length(rules.Properties.VariableNames)
            trialAll(tIndex).(rules.Properties.VariableNames{vIndex}) = rules(idx, :).(rules.Properties.VariableNames{vIndex});
        end
    
        trialAll(tIndex).key = trialsData(tIndex).key;

        if isempty(trialAll(tIndex).key)
            continue;
        end
    
        if trialsData(tIndex).key == 0
            trialAll(tIndex).correct = false;
            trialAll(tIndex).miss = true;
            trialAll(tIndex).RT = inf;
        else
            trialAll(tIndex).miss = false;
            if (~ismember(idx, controlIdx) && trialsData(tIndex).key == 37) || (ismember(idx, controlIdx) && trialsData(tIndex).key == 39)
                trialAll(tIndex).correct = true;
            else
                trialAll(tIndex).correct = false;
            end
            trialAll(tIndex).RT = trialsData(tIndex).push - trialsData(tIndex).offset;
        end
    end

    return;
end