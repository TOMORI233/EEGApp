function passiveFcn(app)
    parseStruct(app.params);
    pID = app.pIDList(app.pIDIndex);
    dataPath = fullfile(app.dataPath, [datestr(now, 'yyyymmdd'), '-', app.subjectInfo.ID]);
    fsDevice = fs * 1e3;

    [sounds, soundNames, fsSound] = loadSounds(pID);

    % Hint for manual starting
    try
        [hintSound, fsHint] = audioread(fullfile(fileparts(mfilename("fullpath")), 'sounds\hint\', [num2str(pID), '.mp3']));
    catch
        [hintSound, fsHint] = audioread(fullfile(fileparts(mfilename("fullpath")), 'sounds\hint\passive start hint.mp3'));
    end
    playAudio(hintSound(:, 1)', fsHint, fsDevice);
    KbGet(32, 20);

    sounds = cellfun(@(x) resampleData(reshape(x, [1, length(x)]), fsSound, fsDevice), sounds, 'UniformOutput', false);
    
    % ITI
    ITI = mode(ITIs(app.pIDsRules == pID));
    
    % nRepeat
    temp = app.nRepeat(app.pIDsRules == pID);
    if length(temp) ~= length(sounds)
        error('rules file does not match sound files.');
    end
    if useSettingnRepeat
        temp(:) = nRepeat;
    else
        temp(isnan(temp)) = nRepeat;
    end
    orders = [];
    for index = 1:length(temp)
        orders  = [orders, repmat(index, 1, temp(index))];
    end 
    orders = orders(randperm(length(orders)));
    
    reqlatencyclass = 2;
    nChs = 2;
    optMode = 1;
    pahandle = PsychPortAudio('Open', [], optMode, reqlatencyclass, fsDevice, nChs);
    PsychPortAudio('Volume', pahandle, volumn); 
    
    pressTime = cell(length(orders), 1);
    key = cell(length(orders), 1);
    startTime = cell(length(orders), 1);
    estStopTime = cell(length(orders), 1);
    soundName = cell(length(orders), 1);
    codes = app.codes(app.pIDsRules == pID);

    rules = readtable(app.rulesPath);
    rules = rules(rules.pID == pID, :);

    mTrigger(triggerType, ioObj, 1, address);
    WaitSecs(2);
    
    for index = 1:length(orders)
        
        if index == 1
            % To prevent burst sound caused by sudden change from zero
            PsychPortAudio('FillBuffer', pahandle, [zeros(1, 10); zeros(1, 10)]);
            PsychPortAudio('Start', pahandle, 1, 0, 1);
            st = PsychPortAudio('Stop', pahandle, 1, 1);

            PsychPortAudio('FillBuffer', pahandle, repmat(sounds{orders(index)}, 2, 1));
            PsychPortAudio('Start', pahandle, 1, st + 0.1, 1);
            t0 = now;
        else
            PsychPortAudio('FillBuffer', pahandle, repmat(sounds{orders(index)}, 2, 1));
            PsychPortAudio('Start', pahandle, 1, startTime{index - 1} + ITI, 1);
        end
        
        % Trigger for EEG recording
        mTrigger(triggerType, ioObj, codes(orders(index)), address);
        
        [startTime{index}, ~, ~, estStopTime{index}] = PsychPortAudio('Stop', pahandle, 1, 1);
        soundName{index} = soundNames{orders(index)};
        app.StateLabel.Text = strcat(app.protocolList.Text{app.protocolList.pID == app.pIDList(app.pIDIndex)}, '(Total: ', num2str(index), '/', num2str(length(orders)), ')');

        % For termination
        pause(0.1);

        if strcmp(app.status, 'stop')
            break;
        end

    end
    
    PsychPortAudio('Close');

    % Time correction
    tShift = t0 * 3600 * 24 - startTime{1};
    startTime = cellfun(@(x) x + tShift, startTime, "UniformOutput", false);
    estStopTime = cellfun(@(x) x + tShift, estStopTime, "UniformOutput", false);
    pressTime = cellfun(@(x) x + tShift, pressTime, "UniformOutput", false);

    trialsData = struct('onset', startTime, ...
                        'offset', estStopTime, ...
                        'soundName', soundName, ...
                        'code', num2cell(codes(orders)), ...
                        'push', pressTime, ...
                        'key', key);
    trialsData(cellfun(@isempty, startTime)) = [];
    
    if ~exist(fullfile(dataPath, [num2str(pID), '.mat']), 'file')
        save(fullfile(dataPath, [num2str(pID), '.mat']), "trialsData", "rules");
    else
        save(fullfile(dataPath, [num2str(pID), '_redo.mat']), "trialsData", "rules");
    end

    WaitSecs(5);

    if strcmp(app.status, 'start')

        if pID == app.pIDList(end)
            app.AddSubjectButton.Enable = 'on';
            app.SetParamsButton.Enable = 'on';
            app.StartButton.Enable = 'off';
            app.NextButton.Enable = 'off';
            app.StopButton.Enable = 'off';
            app.PhaseSelectPanel.Enable = 'on';
            app.DataPathPanel.Enable = 'on';
            app.StateLabel.Text = '本次试验已完成';
            [hintSound, fsHint] = audioread(fullfile(fileparts(mfilename("fullpath")), 'sounds\hint\end of all.mp3'));
            playAudio(hintSound(:, 1)', fsHint, fsDevice);
        else
            [hintSound, fsHint] = audioread(fullfile(fileparts(mfilename("fullpath")), 'sounds\hint\end of section.mp3'));
            playAudio(hintSound(:, 1)', fsHint, fsDevice);
            app.NextButton.Enable = 'on';
            app.timerInit;
            start(app.mTimer);
        end
    
        drawnow;
    end

    return;
end