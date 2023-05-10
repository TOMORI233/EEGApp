# User Guide

#### MATLAB PTB与App设置

1. 安装MATLAB 2020b及以上版本
2. 将`Psychtoolbox`和`Gstreamer`文件夹放在合适位置
3. 右键我的电脑-属性-高级系统设置-环境变量-系统变量-新建

> 变量名: `GSTREAMER_1_0_ROOT_MSVC_X86_64`
>
> 变量值: `根路径\gstreamer\1.0\msvc_x86_64\`

4. 在MATLAB中打开`根路径\Psychtoolbox-3-3.xx\Psychtoolbox`，打开运行`SetupPsychtoolbox.m`。MATLAB命令行中若无`Screen()无法使用`的相关提示则表明配置完成，否则检查`Gstreamer`的安装（可自行另外下载安装`PTB`和`Gstreamer`，配置方法相同）
5. 运行`for_redistribution`文件夹下的`MyAppInstaller.mcr`完成`MATLAB_runtime`的本地安装
6. 运行`for_redistribution_files_only`文件夹下的`MyApp.exe`即可

#### LTP并口设置

1. 将`MATLAB LTP Config`文件夹下的`inpoutx64.dll`和`inpoutx64.sys`文件复制或移动至`C:\Windows\System32\`目录下

1. 运行`**\MATLAB LTP Config\InpOutBinaries_1501\Win32\InstallDriver.exe`

2. 将`MATLAB LTP Config`下的`config_io.m`、`inp.m`、`outp.m`和`io64.mexw64`加入MATLAB的路径

3. 在MATLAB中运行`config_io.m`成功则表示配置完成

4. ```matlab
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

#### Neuracle TriggerBox设置

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

