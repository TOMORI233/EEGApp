function ioObj = InitTrigger(triggerType)
    if strcmpi(triggerType, 'LTP')
        % For curry8 and LTP test
        ioObj = io64;
        status = io64(ioObj);
    elseif strcmpi(triggerType, 'triggerBox')
        % % For neuracle
        ioObj = TriggerBox();
    elseif strcmpi(triggerType, 'None')
        ioObj = [];
    else
        error('Invalid trigger type.');
    end

    return;
end