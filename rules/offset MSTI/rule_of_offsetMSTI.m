addpath(genpath(fileparts(fileparts(mfilename("fullpath")))), '-begin');
cd(fileparts(mfilename("fullpath")));
rootPath = '..\..\sounds';
folders = dir(rootPath);
folders(contains({folders.name}', [".", "..", "hint"])) = [];
pID = str2double(string({folders.name}));
soundDir = string(cellfun(@(x) [rootPath, '\', num2str(x)], num2cell(pID), "UniformOutput", false));
rulesPath = '..\rules\offset MSTI\rules offsetMSTI.xlsx';
mkdir(fileparts(rulesPath));
node0Hint = ["offset被动", "offset被动", "MSTI被动", "offset主动"];
nodeHint = ["阶段一-ICI Screening", "阶段二-Duration(4+16ms)", "阶段一-3ms/18.6ms", "阶段一-ICI Screening"];
apType = ["passive", "passive", "passive", "active"];
protocol = ["passive1", "passive2", "passive3", "active1"];
ISI = [3, 3, 12, 3.5];
nRepeat = [40, 40, 40, 60];
cueLag = [0, 0, 0, 0.8]; % sec
for pIndex = 1:length(pID)
rulesGenerator(soundDir(pIndex), rulesPath, pID(pIndex), ...
                        node0Hint(pIndex), nodeHint(pIndex), ... % shown in UI phase selection nodetree
                        apType(pIndex), ... % "active" or "passive"
                        protocol(pIndex), ... % protocol name, eg "TB passive1", "Offset active2"
                        ISI(pIndex), ...
                        nRepeat(pIndex), ... scalar (for all) or vector (for single)
                        cueLag(pIndex))  % for active protocols, the time lag from the offset of prior sound to the cue for choice                 
end