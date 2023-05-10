function [sounds, soundNames, fs, controlIdx] = loadSounds(pID)
    folders = dir(fullfile(fileparts(mfilename("fullpath")), 'sounds'));
    targetFolder = folders(arrayfun(@(x) isequal(str2double(x.name), pID), folders));
    files = dir(fullfile(fileparts(mfilename("fullpath")), 'sounds', targetFolder.name));
    [~, soundNames, exts] = cellfun(@(x) fileparts(x), {files.name}, "UniformOutput", false);
    soundPaths = arrayfun(@(x) fullfile(x.folder, x.name), files(strcmp(exts, '.wav')), "UniformOutput", false);
    soundNames = soundNames(3:end)';
    controlIdx = contains(soundNames, 'Control');
    [sounds, fs] = cellfun(@audioread, soundPaths, "UniformOutput", false);
    fs = fs{1};
    return;
end