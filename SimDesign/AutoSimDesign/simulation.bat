@echo off
echo =======================================================
echo   Starting ModelSim Simulation (Absolute Path)
echo =======================================================

:: 1. 定义 .do 文件所在的目录路径
::!!此处需要修改!! 替换为你的项目路径，到.do所在的文件夹就可以了
set "WORK_DIR=X:\xxx\xxx"

:: 2. 切换到工作目录 (使用 /d 参数可以同时切换驱动器号 E: 和目录)
cd /d "%WORK_DIR%"

:: 3. 设定 modelsim 的绝对路径和 .do 文件的绝对路径进行仿真
::!!此处需要修改!! 替换为你的vsim.exe具体路径
set "VSIM_PATH=X:\modeltech64_2020.4\win64\vsim.exe"
::!!此处需要修改!! 替换为你的.do文件的具体路径
set "DO_FILE=E:\7MLAF_6V_prj_500fps\2024_0313_500fps\testbench\img_roi_crop_tb\autosim.do"

:: 4. 启动 ModelSim
echo Running: "%VSIM_PATH%" -do "%DO_FILE%"
"%VSIM_PATH%" -do "%DO_FILE%"

echo =======================================================
echo   ModelSim Closed or Script Finished.
echo =======================================================
pause