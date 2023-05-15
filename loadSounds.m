function [sounds, soundNames, fs, controlIdx] = loadSounds(arg)
    rootPath = fileparts(mfilename("fullpath"));

    switch class(arg)
        case "double"
            pID = arg;
            folders = dir(fullfile(rootPath, 'sounds'));
            targetFolder = folders(arrayfun(@(x) isequal(str2double(x.name), pID), folders));
            files = dir(fullfile(rootPath, 'sounds', targetFolder.name));
        case "string"
            files = dir(arg);
        case "char"
            files = dir(arg);
        otherwise
            error("Input should be pID or folder path");
    end

    [~, soundNames, exts] = cellfun(@(x) fileparts(x), {files.name}, "UniformOutput", false);
    soundPaths = arrayfun(@(x) fullfile(x.folder, x.name), files(strcmp(exts, '.wav')), "UniformOutput", false);
    soundNames = soundNames(3:end)';
    controlIdx = contains(soundNames, 'Control');
    [sounds, fs] = cellfun(@audioread, soundPaths, "UniformOutput", false);
    fs = fs{1};
    return;
end