@echo off
echo 安装 Dify Plugin Repackager...

set "INSTALL_DIR=%PROGRAMFILES%\DifyPluginRepackager"
set "SCRIPT_DIR=%~dp0"

:: 检查管理员权限
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo 请以管理员身份运行此安装程序
    pause
    exit /b 1
)

:: 创建安装目录
echo 创建安装目录: %INSTALL_DIR%
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

:: 复制文件
echo 复制文件到 %INSTALL_DIR%...
xcopy "%SCRIPT_DIR%*" "%INSTALL_DIR%\" /E /I /Y >nul

:: 创建桌面快捷方式
echo 创建桌面快捷方式...
powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%PUBLIC%\Desktop\Dify Plugin Repackager.lnk'); $Shortcut.TargetPath = '%INSTALL_DIR%\DifyPluginRepackager.exe'; $Shortcut.WorkingDirectory = '%INSTALL_DIR%'; $Shortcut.IconLocation = '%INSTALL_DIR%\icon.ico'; $Shortcut.Save()"

:: 创建开始菜单快捷方式
echo 创建开始菜单快捷方式...
set "START_MENU=%PROGRAMDATA%\Microsoft\Windows\Start Menu\Programs"
powershell -Command "$WshShell = New-Object -comObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%START_MENU%\Dify Plugin Repackager.lnk'); $Shortcut.TargetPath = '%INSTALL_DIR%\DifyPluginRepackager.exe'; $Shortcut.WorkingDirectory = '%INSTALL_DIR%'; $Shortcut.IconLocation = '%INSTALL_DIR%\icon.ico'; $Shortcut.Save()"

echo.
echo 安装完成！
echo.
echo 您可以通过以下方式启动:
echo 1. 双击桌面上的 "Dify Plugin Repackager" 快捷方式
echo 2. 从开始菜单启动
echo 3. 直接运行: %INSTALL_DIR%\DifyPluginRepackager.exe
echo.
pause
