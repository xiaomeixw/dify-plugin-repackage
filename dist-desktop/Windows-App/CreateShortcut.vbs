Set WshShell = CreateObject("WScript.Shell")
Set oMyShortcut = WshShell.CreateShortcut(WshShell.SpecialFolders("Desktop") & "\Dify Plugin Repackager.lnk")
oMyShortcut.TargetPath = WshShell.CurrentDirectory & "\DifyPluginRepackager.exe"
oMyShortcut.WorkingDirectory = WshShell.CurrentDirectory
oMyShortcut.IconLocation = WshShell.CurrentDirectory & "\icon.ico"
oMyShortcut.Description = "Dify Plugin Repackaging Tool"
oMyShortcut.Save
WScript.Echo "桌面快捷方式已创建"
