# User Guide

Git项目地址`git@github.com:TOMORI233/EEGApp.git`

#### 1. MATLAB PTB与App设置

1. 安装**`MATLAB 2020b`**及以上版本（**`MATLAB 2022a`**对部分`cell`类型的运算不兼容，可能会遇到意料之外的问题，不推荐），以及在附加功能中安装以下工具包：

> Signal processing toolbox

2. 本项目使用需要`MATLABUtils`项目，Git地址`git@github.com:TOMORI233/MATLABUtils.git`

3. 将**`Psychtoolbox`**和**`Gstreamer`**文件夹放在合适位置

4. 右键 `我的电脑`-`属性`-`高级系统设置`-`环境变量`-`系统变量`-`新建`

> 变量名: `GSTREAMER_1_0_ROOT_MSVC_X86_64`
>
> 变量值: `根路径\gstreamer\1.0\msvc_x86_64\`

5. 在MATLAB中打开`根路径\Psychtoolbox-3-3.xx\Psychtoolbox`，打开运行`SetupPsychtoolbox.m`。MATLAB命令行中若无`Screen()无法使用`的相关提示则表明配置完成，否则检查`Gstreamer`的安装（可自行另外下载安装`PTB`和`Gstreamer`，配置方法相同）

以下针对已经打包的App：

6. 运行`for_redistribution`文件夹下的`MyAppInstaller.mcr`完成`MATLAB_runtime`的本地安装（注意runtime版本，请安装用于打包`*.exe`的版本）

7. 运行`for_redistribution_files_only`文件夹下的`MyApp.exe`即可

#### 2. LTP并口设置（Neuroscan）

1. 运行`MATLAB LTP Config\InpOutBinaries_1501\Win32\InstallDriver.exe`

2. 将`MATLAB LTP Config\`文件夹下的`inpoutx64.dll`和`inpoutx64.sys`文件复制或移动至`C:\Windows\System32\`目录下

3. 将`MATLAB LTP Config\`下的`config_io.m`、`inp.m`、`outp.m`和`io64.mexw64`加入MATLAB的路径
4. 在MATLAB中运行`config_io.m`成功则表示配置完成（失败请重启电脑）

```matlab
%% Init IO
ioObj = io64();
status = io64(ioObj);

%% Output event
address = hex2dec('378'); % decimal
code = 100; % range 0~255
io64(ioObj, address, code);
WaitSecs(0.01); % PTB API for pausing
io64(ioObj, address, 0);
```

#### 3. Neuracle TriggerBox设置（Neuracle）

1. 右键以管理员身份运行`Recorder-TxCSSupport_Base_4200-202101210-48cb850b\Driver`下的`CDM v2.12.12 WHQL Certified.exe`，安装TriggerBox的USB驱动

2. 将`Recorder-TxCSSupport_Base_4200-202101210-48cb850b\TriggerBox`下的`TriggerBox.m`加入MATLAB路径

3. ```matlab
   % 请保证TriggerBox已连接再进行测试
   %% Init triggerBox
   mTriggerBox = TriggerBox();
   
   %% Output event
   code = 100; % range 0~255
   mTriggerBox.OutputEventData(code);
   ```

#### 4. App使用

1. 编辑`rules.xlsx`，请务必按loadSounds导出的顺序填写，务必，务必，务必，务必！（强烈建议所有文件以数字`1_, 2_, 3_, ...`开头以便按一定顺序读取，对于超过10的请使用`001, 002, ..., 100, 101, ...`开头，MATLAB读取文件的文件名排序为数字-大写字母-小写字母）

```matlab
% 生成声音时按一定顺序
% 文件命名 ord_param1-param1Val_param2-param2Val_...
% ord 001, 002, ..., 249, 250
ord = arrayfun(@(x) strrep(x, ' ', '0'), num2str((1:250)'));
for index = 1:length(nSounds)
    filename = [ord(index, :), '_param1-', num2str(param1Val), '_param2', num2str(param2Val), '_', otherParamsNameValue, '.wav'];
    audiowrite(filename, y{index}, fs);
end

% 使用rulesGenerator.m根据文件名自动生成rules.xlsx
% 将pID=2的rules强制拼接至原rules.xlsx表格下（新增原来不存在的列）
% 在rules.xlsx中可以单独编辑某个声音的重复次数和间隔
ITI = 5;
pID = 2;
nRepeat = 40;
rulesGenerator(fullfile("sounds", num2str(pID)), ...
			   "rules.xlsx", ...
			   pID, ...
			   "测试父节点", "测试子节点1", ...
			   "passive", ...
			   "Test Phase1", ...
			   ITI, ...
			   nRepeat, ...
			   "forceOpt", "on");
```

2. 将声音刺激文件放进对应`sounds\{pID}\`数字命名的文件夹下
3. 命令行输入`mainApp`打开主界面
4. 编辑被试信息：带*号为必填项
5. 编辑刺激参数：请反复确认默认播放设备的采样率以及触发方式，默认为None即无触发，可选触发方式包括：LTP、COM和TriggerBox
6. 在nodetree中勾选需要完成的protocol
6. 可选：在有行为的实验中打开实时行为查看窗口
7. 开始记录，同时自动将参数保存在数据存储路径和本项目根目录下的`config.mat`中
8. 完成一个protocol的记录，自动保存数据为`[pID].mat`，手动/自动进入下一阶段。保存的内容包括：trial数据（onset, offset, soundName, push, key，时间为系统时间，可用`datestr(t, "yyyy-mm-dd HH:MM:SS.FFF")`转为时间戳，单位：sec）、pID、rules、protocol名。同时在该目录下也会保存一个`config.mat`
9. 自动/手动（强制）结束记录

#### 5. 注意事项：

1. ~~`rules.xlsx`未指定的nRepeat的声音，将默认使用设置界面中的nRepeat，其中文件名带`Control`的为界面中的nRepeat/3（指定了则不会/3）~~ 文件名带Control将不再影响次数，请在相应`rules.xlsx`中对`nRepeat`进行设置。

2. 可以在参数设置中勾选`强制`以将该重复次数应用于所有声音。

3. pID应小于10000（父节点的NodeData为10000+i，其中i为父节点序号）。

4. 建议把自己的protocol对应的rules建一个文件夹放在`rules\`路径下，如`rules\offset MSTI\`

5. 每个人分配100个可用pID，请在`sounds\`文件夹下创建自己`pID\`的声音文件夹，请勿越界使用。分配关系如下：

| 主试 | 可用pID范围 |
| :--: | :---------: |
| XHX  |   100~199   |
| HQY  |   200~299   |
| ZYY  |   300~399   |
| SPR  |   400~499   |

6. 在有行为的实验中，请保证ISI > sound duration + choiceWin + 0.5，否则在Miss时可能会出现到下一个trial的计时不准。

#### 6. Update Log

请将每次更新内容**置顶**写在这里，标注日期、修改者和兼容性（**Incompatible**/Compatible），对每条修改请标注修改类型（Add/Modify/Delete/Debug）。若为Incompatible，请给出修改方案。

- 2023/08/14 by XHX - **Incompatible**

  | Type           | Target             | Content                                          |
  | -------------- | ------------------ | ------------------------------------------------ |
  | Modify & Debug | `rulesGenerator.m` | 将`ISI`重命名为`ITI`，如果处理程序用到了请注意。 |

- 2023/08/01 by XHX - Compatible （重要更新）

  | Type         | Target                                                       | Content                                                      |
  | ------------ | ------------------------------------------------------------ | ------------------------------------------------------------ |
  | Add & Modify | `behaviorPlotApp.mlapp`, `mainApp.mlapp`, `activeFcn.m`, `generalProcessFcn.m`, `rulesGenerator.m` | 增加实时查看行为结果的子App，可以在主界面中按`实时行为查看`按钮打开，需要在`rules.xlsx`中通过`processFcn`字段指定函数句柄以调用处理画图程序，行为处理程序可以统一使用`generalProcessFcn.m`，请将写好的处理程序放在根目录下的`processFcn\`目录下。在`rulesGenerator.m`中增加了固定规则字段`processFcn`，输入类型为函数句柄标量。 |

- 2023/07/29 by XHX - Compatible

  | Type        | Target             | Content                                                      |
  | ----------- | ------------------ | ------------------------------------------------------------ |
  | Modify      | 项目结构           | 将`LTP`和`TriggerBox`的相关模块放在了根目录下的`Trigger\`文件夹下 |
  | Add & Debug | `rulesGenerator.m` | 增加`name-value`输入参数`forceOpt`，当该选项被设置为`"on"`时，在尝试拼接失败后，强制将新增protocol的参数拼接在原始`rules.xlsx`中，之前存在的参数正常拼接，不存在的参数则在原本的行位置留空。选项默认`"off"`，即首先尝试拼接，如果有冲突则新建`rules_pID-[pID].xlsx`对新的protocol参数单独保存。 |

- 2023/07/18 by XHX - Compatible

  | Type   | Target                        | Content                                                      |
  | :----- | ----------------------------- | :----------------------------------------------------------- |
  | Modify | `activeFcn.m`, `passiveFcn.m` | 为了使第一个声音放出时不会出现burst，会先播放10个sample的0，并添加了100 ms的延迟再放实际声音，不影响实际给声音（参考`playAudio.m`） |
  | Modify | `mainApp.mlapp`               | 调整pID上限：~~100~~→10000                                   |
  | Add    | `activeFcn.m`, `passiveFcn.m` | 在完成每个protocol后，保存的`*.mat`内容增加了`pID`和`rules`，方便在处理时读取 |

- 2023/07/03 by XHX - Compatible

  | Type   | Target                   | Content                                                      |
  | ------ | ------------------------ | ------------------------------------------------------------ |
  | Delete | ~~`playAudio.m`~~        | 删除了本项目根目录下的`playAudio.m`，请使用`MATLABUtils\toolbox API\PTB\playAudio.m`，有特殊更改请创建自己名字的`+xxx`工具包 |
  | Add    | `paramsSettingApp.mlapp` | 添加了对`COM`触发的支持                                      |
