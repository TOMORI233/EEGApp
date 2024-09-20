function trialsData = activeFcn(app)
    parseStruct(app.params);
    pID = app.pIDList(app.pIDIndex);
    dataPath = fullfile(app.dataPath, [datestr(now, 'yyyymmdd'), '-', app.subjectInfo.ID]);
    fsDevice = fs * 1e3;
    
    [sounds, soundNames, fsSound] = loadSounds(pID);
    
    % Load hint sound
    if exist(fullfile(fileparts(mfilename("fullpath")), 'sounds\hint\', [num2str(pID), '.mp3']), "file")
        [hintSound, fsHint] = audioread(fullfile(fileparts(mfilename("fullpath")), 'sounds\hint\', [num2str(pID), '.mp3']));
    else
        [hintSound, fsHint] = audioread(fullfile(fileparts(mfilename("fullpath")), 'sounds\hint\active start hint.mp3'));
    end
    
    % Load cue sound
    if exist(fullfile(fileparts(mfilename("fullpath")), 'sounds\hint\cue.wav'), "file")
        [cueSound, fsCue] = audioread(fullfile(fileparts(mfilename("fullpath")), 'sounds\hint\cue.wav'));

        if ~isequal(fsSound, fsDevice)
            cueSound = resampleData(cueSound, fsCue, fsDevice);
        end

        if size(cueSound, 2) == 1
            cueSound = repmat(cueSound(:)', 2, 1);
        elseif size(cueSound, 2) == 2
            cueSound = cueSound';
        else
            error("The number of cue sound channels should not be greater than 2.");
        end

    end

    % Load rules
    rules = readtable(app.rulesPath);
    rules = rules(rules.pID == pID, :);
    
    % ITI
    ITI = mode(ITIs(app.pIDsRules == pID));

    % ITI jitter
    itiJitter = getOr(app.params, "itiJitter"); % sec
    
    % nRepeat & cueLag
    temp = app.nRepeat(app.pIDsRules == pID);
    tempCue = app.cueLag(app.pIDsRules == pID);

    if length(temp) ~= length(sounds) || length(tempCue) ~= length(sounds)
        error('rules file does not match sound files.');
    end

    if useSettingnRepeat
        temp(:) = nRepeat;
    else
        temp(isnan(temp)) = nRepeat;
    end

    tempCue(isnan(tempCue)) = cueLag;
    orders = [];
    cueLags = [];

    for index = 1:length(temp)
        orders = [orders, repmat(index, 1, temp(index))];
        cueLags = [cueLags, tempCue(index) * ones(1, temp(index))];
    end

    % Resample
    % sound is a [nsample, nch] double matrix
    if ~isequal(fsSound, fsDevice)
        sounds = cellfun(@(x) resampleData(x, fsSound, fsDevice), sounds, 'UniformOutput', false);
    end

    % Convert single-channel sound wave to 2-channel sound wave
    sz = cellfun(@size, sounds, "UniformOutput", false);

    if ~all(cellfun(@(x) isequal(x(2), sz{1}(2)), sz))
        warning("Not all sounds have the same channel number.");
        nchs = cellfun(@(x) x(2), sz);

        if any(nchs > 2)
            error("The number of sound channels should not be greater than 2.");
        end

        idx = nchs == 1;
        sounds(idx) = cellfun(@(x) repmat(x(:)', 2, 1), sounds(idx), "UniformOutput", false);
        sounds(~idx) = cellfun(@(x) x', sounds(~idx), "UniformOutput", false);
    else

        if size(sounds{1}, 2) == 1
            sounds = cellfun(@(x) repmat(x(:)', 2, 1), sounds, "UniformOutput", false);
        end

    end

    % Play hint sound
    playAudio(hintSound, fsHint, fsDevice);

    % Wait for keyboard response
    KbGet(32, 20);

    % Randomize orders
    idx = randperm(length(orders));
    orders = orders(idx);
    cueLags = cueLags(idx);
    
    % Parameter setting for PTB
    reqlatencyclass = 2;
    nChs = 2;
    optMode = 1;
    pahandle = PsychPortAudio('Open', [], optMode, reqlatencyclass, fsDevice, nChs);
    PsychPortAudio('Volume', pahandle, volumn);
    
    % Init variables
    pressTime = cell(length(orders), 1);
    key = cell(length(orders), 1);
    startTime = cell(length(orders), 1);
    estStopTime = cell(length(orders), 1);
    soundName = cell(length(orders), 1);
    codes = app.codes(app.pIDsRules == pID);

    if ~isempty(itiJitter)
        itiJitters = (rand(length(orders), 1) * 2 - 1) * itiJitter;
    else
        itiJitters = zeros(length(orders), 1);
    end

    % Init monitor app
    if isa(app.behavApp, "behaviorPlotApp") && isvalid(app.behavApp)
        % Call behaviorPlotApp if processFcn is specified
        if ~isempty(rules.processFcn)
            app.behavApp.processFcn = str2func(rules(1, :).processFcn{1});
            drawnow;
        else
            disp('WARNING: processFcn not specified!');
        end
    else
        disp('INFO: Real-time monitor is not created or is deleted.');
    end
    
    mTrigger(triggerType, ioObj, 1, address);
    WaitSecs(2);
    
    nMiss = 0;
    orders = orders(:);
    
    for index = 1:length(orders)

        if index == 1
            % To prevent burst sound caused by sudden change from zero
            PsychPortAudio('FillBuffer', pahandle, [zeros(1, 10); zeros(1, 10)]);
            PsychPortAudio('Start', pahandle, 1, 0, 1);
            st = PsychPortAudio('Stop', pahandle, 1, 1);

            PsychPortAudio('FillBuffer', pahandle, sounds{orders(index)});
            PsychPortAudio('Start', pahandle, 1, st + 0.1, 1);
            t0 = now;
        else
            PsychPortAudio('FillBuffer', pahandle, sounds{orders(index)});
            if isinf(choiceWin)
                PsychPortAudio('Start', pahandle, 1, pressTime{index - 1} + ITI + itiJitters(index) - size(sounds{orders(index)}, 2) / fsDevice, 1);
            else
                PsychPortAudio('Start', pahandle, 1, startTime{index - 1} + ITI + itiJitters(index), 1);
            end
        end

        % Trigger for EEG recording
        mTrigger(triggerType, ioObj, codes(orders(index)), address);

        [startTime{index}, ~, ~, estStopTime{index}] = PsychPortAudio('Stop', pahandle, 1, 1);
    
        if cueLags(index) > 0
            PsychPortAudio('FillBuffer', pahandle, repmat(cueSound, 2, 1));
            PsychPortAudio('Start', pahandle, 1, startTime{index} + size(sounds{orders(index)}, 2) / fsSound + cueLags(index), 1);
            PsychPortAudio('Stop', pahandle, 1, 1);
        end

        [pressTime{index}, key{index}] = KbGet([37, 39], choiceWin);
    
        if key{index} == 37 % left arrow
            mTrigger(triggerType, ioObj, 2, address); % diff
        elseif key{index} == 39 % right arrow
            mTrigger(triggerType, ioObj, 3, address); % same
        else
            nMiss = nMiss + 1;
        end
    
        soundName{index} = soundNames{orders(index)};
        app.StateLabel.Text = strcat(app.protocolList.Text{app.protocolList.pID == app.pIDList(app.pIDIndex)}, '(Total: ', num2str(index), '/', num2str(length(orders)), ', Miss: ', num2str(nMiss), ')');
        
        % Update behavior plot
        if isa(app.behavApp, "behaviorPlotApp") && isvalid(app.behavApp) && ~isempty(rules.processFcn)
            try % In case that error occurs in your processFcn
                app.behavApp.processFcn = str2func(rules(1, :).processFcn{1});
                app.behavApp.processFcn(app.behavApp, ...
                                        rules, ...
                                        startTime, ...
                                        estStopTime, ...
                                        num2cell(codes(orders)), ...
                                        pressTime, ...
                                        key);
            end
        end

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
            playAudio(hintSound, fsHint, fsDevice);
        else
            [hintSound, fsHint] = audioread(fullfile(fileparts(mfilename("fullpath")), 'sounds\hint\end of section.mp3'));
            playAudio(hintSound, fsHint, fsDevice);
            app.NextButton.Enable = 'on';
            app.timerInit;
            start(app.mTimer);
        end
    
        drawnow;
    end
    
    return;
end