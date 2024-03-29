ccc;
mfilepath = fileparts(mfilename("fullpath"));
ROOTPATH = fullfile(getRootDirPath(mfilepath, 2), "sounds");

% 预实验-阈值
pID = 101;
ITI = 4; % sec
nRepeat = 2;
rulesGenerator(fullfile(ROOTPATH, num2str(pID)), ...
               fullfile(mfilepath, "rules_SE.xlsx"), ...
               pID, ...
               "start-end效应部分", ...
               "预实验阶段-阈值", ...
               "active", ...
               "SE active0", ...
               ITI, ...
               nRepeat, ...
               [], ...
               @seEffectThProcessFcn, ...
               "forceOpt", "on");

% 第一阶段-阈值-1k
pID = 102;
ITI = 3; % sec
nRepeat = 25;
rulesGenerator(fullfile(ROOTPATH, num2str(pID)), ...
               fullfile(mfilepath, "rules_SE.xlsx"), ...
               pID, ...
               "start-end效应部分", ...
               "第一阶段-阈值-1k", ...
               "active", ...
               "SE active1", ...
               ITI, ...
               nRepeat, ...
               [], ...
               @seEffectThProcessFcn, ...
               "forceOpt", "on");

% 第二阶段-阈值-xk
pID = 103;
ITI = 3; % sec
nRepeat = 25;
rulesGenerator(fullfile(ROOTPATH, num2str(pID)), ...
               fullfile(mfilepath, "rules_SE.xlsx"), ...
               pID, ...
               "start-end效应部分", ...
               "第一阶段-阈值-xk", ...
               "active", ...
               "SE active2", ...
               ITI, ...
               nRepeat, ...
               [], ...
               @seEffectThProcessFcn, ...
               "forceOpt", "on");

% 第三阶段-位置
pID = 104;
ITI = 4; % sec
nRepeat = 30;
rulesGenerator(fullfile(ROOTPATH, num2str(pID)), ...
               fullfile(mfilepath, "rules_SE.xlsx"), ...
               pID, ...
               "start-end效应部分", ...
               "第三阶段-位置", ...
               "active", ...
               "SE active3", ...
               ITI, ...
               nRepeat, ...
               [], ...
               @seEffectLocProcessFcn, ...
               "forceOpt", "on");

% 第四阶段-MMN
pID = 105;
ITI = 10; % sec
nRepeat = 40;
rulesGenerator(fullfile(ROOTPATH, num2str(pID)), ...
               fullfile(mfilepath, "rules_SE.xlsx"), ...
               pID, ...
               "start-end效应部分", ...
               "第四阶段-MMN", ...
               "passive", ...
               "SE passive1", ...
               ITI, ...
               nRepeat, ...
               "forceOpt", "on");