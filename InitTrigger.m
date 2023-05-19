function ioObj = InitTrigger(triggerType, COM)
    if strcmpi(triggerType, 'LTP')
        % For curry8 and LTP test
        ioObj = io64;
        status = io64(ioObj); %#ok<NASGU>
    elseif strcmpi(triggerType, 'triggerBox')
        % % For neuracle
        ioObj = TriggerBox();
    elseif strcmpi(triggerType, 'None')
        ioObj = [];
    elseif strcmpi(triggerType, 'COM')
        delete(instrfindall);
        ioObj = serialport(strcat("COM", num2str(COM)), 115200);
    else
        error('Invalid trigger type.');
    end

    return;
end