# User Guide

#### 1. MATLAB PTB与App设置

1. 安装MATLAB 2020b及以上版本
2. 将`Psychtoolbox`和`Gstreamer`文件夹放在合适位置
3. 右键我的电脑-属性-高级系统设置-环境变量-系统变量-新建

> 变量名: `GSTREAMER_1_0_ROOT_MSVC_X86_64`
>
> 变量值: `根路径\gstreamer\1.0\msvc_x86_64\`

4. 在MATLAB中打开`根路径\Psychtoolbox-3-3.xx\Psychtoolbox`，打开运行`SetupPsychtoolbox.m`。MATLAB命令行中若无`Screen()无法使用`的相关提示则表明配置完成，否则检查`Gstreamer`的安装（可自行另外下载安装`PTB`和`Gstreamer`，配置方法相同）
5. 运行`for_redistribution`文件夹下的`MyAppInstaller.mcr`完成`MATLAB_runtime`的本地安装
6. 运行`for_redistribution_files_only`文件夹下的`MyApp.exe`即可

#### 2. LTP并口设置

1. 运行`**\MATLAB LTP Config\InpOutBinaries_1501\Win32\InstallDriver.exe`

2. 将`MATLAB LTP Config`文件夹下的`inpoutx64.dll`和`inpoutx64.sys`文件复制或移动至`C:\Windows\System32\`目录下

3. 将`MATLAB LTP Config`下的`config_io.m`、`inp.m`、`outp.m`和`io64.mexw64`加入MATLAB的路径
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

#### 3. Neuracle TriggerBox设置

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

1. 编辑`rules.xlsx`，请务必按loadSounds导出的顺序填写，务必，务必，务必，务必！（强烈建议所有文件以数字`1_, 2_, 3_, ...`开头以便按一定顺序读取）
2. 将刺激文件放进对应`sounds\{pID}`数字命名的文件夹下
3. 命令行输入`mainApp`打开主界面
4. 编辑被试信息
5. 编辑刺激参数
6. 开始记录

- 注意事项：
  - `rules.xlsx`未指定的nRepeat的声音，将默认使用设置界面中的nRepeat，其中文件名带`Control`的为界面中的nRepeat/3（指定了则不会/3）
