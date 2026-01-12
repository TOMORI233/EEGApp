function mTrigger(triggerType, ioObj, code, address)
    tNow = datetime("now", "Format", "yyyy-MM-dd HH:mm:ss.SSS");
    disp(['Trigger: ', num2str(code), ' (', char(tNow), ')']);

    if strcmpi(triggerType, 'LTP')
        % For LTP (curry 8)
        io64(ioObj, address, code);
        WaitSecs(0.01);
        io64(ioObj, address, 0);
    elseif strcmpi(triggerType, 'triggerBox')
        % For neuracle
        ioObj.OutputEventData(code);
    elseif strcmpi(triggerType, 'None')
        % For no trigger
    elseif strcmpi(triggerType, 'COM')
        % For COM
        write(ioObj, code, 'uint8');
    else
        error('Invalid trigger type.');
    end

end