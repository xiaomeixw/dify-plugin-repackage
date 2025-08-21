#!/bin/bash

# 桌面应用程序构建脚本
set -e

# 设置颜色变量
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 获取脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR"
PROJECT_ROOT=$(cd .. && pwd)

# 设置输出目录
OUTPUT_DIR="$PROJECT_ROOT/dist-desktop"
SOURCE_DIR="$PROJECT_ROOT/cmd/repackage-gui"
REPACKAGE_DIR="$PROJECT_ROOT/cmd/repackage"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  构建桌面应用程序${NC}"
echo -e "${BLUE}========================================${NC}"

# 清理并创建输出目录
echo -e "${YELLOW}清理并创建输出目录...${NC}"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

cd "$PROJECT_ROOT"

# 创建应用程序图标（简单的SVG图标）
create_app_icon() {
    local icon_dir="$1"
    mkdir -p "$icon_dir"
    
    # 创建SVG图标
    cat > "$icon_dir/icon.svg" << 'EOF'
<svg width="512" height="512" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#0d6efd;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#0a58ca;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="512" height="512" rx="80" fill="url(#grad1)"/>
  <g fill="white">
    <!-- 包裹图标 -->
    <rect x="128" y="128" width="256" height="192" rx="16" fill="none" stroke="white" stroke-width="16"/>
    <rect x="160" y="160" width="64" height="48" rx="8" fill="white"/>
    <rect x="240" y="160" width="64" height="48" rx="8" fill="white"/>
    <rect x="160" y="224" width="192" height="16" rx="8" fill="white"/>
    <rect x="160" y="256" width="128" height="16" rx="8" fill="white"/>
    
    <!-- 下载箭头 -->
    <path d="M384 320 L384 384 L448 384 L448 320 Z" fill="white"/>
    <path d="M400 320 L416 336 L432 320" fill="none" stroke="white" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M416 280 L416 336" stroke="white" stroke-width="8" stroke-linecap="round"/>
  </g>
  
  <!-- 应用名称 -->
  <text x="256" y="450" text-anchor="middle" fill="white" font-family="Arial, sans-serif" font-size="36" font-weight="bold">Dify</text>
  <text x="256" y="480" text-anchor="middle" fill="white" font-family="Arial, sans-serif" font-size="24">Repackager</text>
</svg>
EOF
}

# 构建Mac应用程序包
build_mac_app() {
    echo -e "${YELLOW}构建Mac应用程序包...${NC}"
    
    local app_name="DifyPluginRepackager"
    local app_dir="$OUTPUT_DIR/$app_name.app"
    local contents_dir="$app_dir/Contents"
    local macos_dir="$contents_dir/MacOS"
    local resources_dir="$contents_dir/Resources"
    
    # 创建目录结构
    mkdir -p "$macos_dir" "$resources_dir"
    
    # 构建GUI可执行文件
    echo -e "${YELLOW}编译Mac GUI可执行文件...${NC}"
    go build -ldflags "-s -w -X main.version=1.0.0-desktop" -o "$macos_dir/$app_name" ./cmd/repackage-gui/
    
    # 构建repackage命令行工具
    go build -ldflags "-s -w -X main.version=1.0.0-desktop" -o "$resources_dir/repackage" ./cmd/repackage/
    
    # 复制必要文件
    cp "$REPACKAGE_DIR/plugin_repackaging.sh" "$resources_dir/"
    
    # 复制所有6个dify-plugin文件到Mac应用程序包
    echo -e "${YELLOW}复制所有平台的dify-plugin文件...${NC}"
    cp "$REPACKAGE_DIR"/dify-plugin-* "$resources_dir/" 2>/dev/null || true
    
    # 确保所有文件都复制成功
    ls -la "$resources_dir"/dify-plugin-* 2>/dev/null || echo "警告: 某些dify-plugin文件可能缺失"
    
    # 设置权限
    chmod +x "$macos_dir/$app_name"
    chmod +x "$resources_dir/repackage"
    chmod +x "$resources_dir/plugin_repackaging.sh"
    chmod +x "$resources_dir"/dify-plugin-* 2>/dev/null || true
    
    # 创建应用图标
    create_app_icon "$resources_dir"
    
    # 如果有ImageMagick，转换SVG到icns
    if command -v convert >/dev/null 2>&1; then
        echo -e "${YELLOW}生成Mac图标...${NC}"
        # 创建不同尺寸的PNG
        local icon_set="$resources_dir/AppIcon.iconset"
        mkdir -p "$icon_set"
        
        # 生成各种尺寸的图标
        for size in 16 32 64 128 256 512; do
            convert "$resources_dir/icon.svg" -resize "${size}x${size}" "$icon_set/icon_${size}x${size}.png"
            if [ $size -le 256 ]; then
                convert "$resources_dir/icon.svg" -resize "$((size*2))x$((size*2))" "$icon_set/icon_${size}x${size}@2x.png"
            fi
        done
        
        # 生成icns文件
        if command -v iconutil >/dev/null 2>&1; then
            iconutil -c icns "$icon_set" -o "$resources_dir/AppIcon.icns"
            rm -rf "$icon_set"
        fi
    fi
    
    # 创建Info.plist
    cat > "$contents_dir/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$app_name</string>
    <key>CFBundleIdentifier</key>
    <string>com.langgenius.dify-plugin-repackager</string>
    <key>CFBundleName</key>
    <string>Dify Plugin Repackager</string>
    <key>CFBundleDisplayName</key>
    <string>Dify Plugin Repackager</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>DFPR</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>difypkg</string>
            </array>
            <key>CFBundleTypeName</key>
            <string>Dify Plugin Package</string>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>LSHandlerRank</key>
            <string>Owner</string>
        </dict>
    </array>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 Langgenius. All rights reserved.</string>
</dict>
</plist>
EOF

    echo -e "${GREEN}✓ Mac应用程序包创建完成: $app_name.app${NC}"
}

# 构建Windows应用程序
build_windows_app() {
    echo -e "${YELLOW}构建Windows应用程序...${NC}"
    
    local app_name="DifyPluginRepackager"
    local app_dir="$OUTPUT_DIR/Windows-App"
    
    mkdir -p "$app_dir"
    
    # 构建Windows可执行文件
    echo -e "${YELLOW}编译Windows GUI可执行文件...${NC}"
    env GOOS=windows GOARCH=amd64 CGO_ENABLED=0 \
        go build -ldflags "-s -w -X main.version=1.0.0-desktop -H windowsgui" \
        -o "$app_dir/$app_name.exe" ./cmd/repackage-gui/
    
    # 构建repackage命令行工具
    env GOOS=windows GOARCH=amd64 CGO_ENABLED=0 \
        go build -ldflags "-s -w -X main.version=1.0.0-desktop" \
        -o "$app_dir/repackage.exe" ./cmd/repackage/
    
    # 复制必要文件
    cp "$REPACKAGE_DIR/plugin_repackaging.sh" "$app_dir/"
    
    # 复制所有6个dify-plugin文件到Windows应用程序
    echo -e "${YELLOW}复制所有平台的dify-plugin文件...${NC}"
    cp "$REPACKAGE_DIR"/dify-plugin-* "$app_dir/" 2>/dev/null || true
    
    # 确保所有文件都复制成功
    ls -la "$app_dir"/dify-plugin-* 2>/dev/null || echo "警告: 某些dify-plugin文件可能缺失"
    
    # 创建应用图标
    create_app_icon "$app_dir"
    
    # 如果有ImageMagick，生成Windows图标
    if command -v convert >/dev/null 2>&1; then
        echo -e "${YELLOW}生成Windows图标...${NC}"
        convert "$app_dir/icon.svg" -resize 256x256 "$app_dir/icon.ico" 2>/dev/null || true
    fi
    
    # 创建快捷方式脚本
    cat > "$app_dir/CreateShortcut.vbs" << 'EOF'
Set WshShell = CreateObject("WScript.Shell")
Set oMyShortcut = WshShell.CreateShortcut(WshShell.SpecialFolders("Desktop") & "\Dify Plugin Repackager.lnk")
oMyShortcut.TargetPath = WshShell.CurrentDirectory & "\DifyPluginRepackager.exe"
oMyShortcut.WorkingDirectory = WshShell.CurrentDirectory
oMyShortcut.IconLocation = WshShell.CurrentDirectory & "\icon.ico"
oMyShortcut.Description = "Dify Plugin Repackaging Tool"
oMyShortcut.Save
WScript.Echo "桌面快捷方式已创建"
EOF

    # 创建安装脚本
    cat > "$app_dir/install.bat" << 'EOF'
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
EOF

    # 创建README
    cat > "$app_dir/README.txt" << EOF
Dify Plugin Repackager - Windows桌面应用

安装方法:
1. 以管理员身份运行 install.bat 进行系统安装
2. 或直接双击 DifyPluginRepackager.exe 运行

功能特点:
- 双击图标即可启动
- 自动打开浏览器界面
- 智能环境检测
- 支持拖拽上传文件
- 三种打包模式

系统要求:
- Windows 10 或更高版本
- Docker (推荐) 或 Python 3.12+
- 现代浏览器

使用说明:
1. 双击应用图标启动
2. 浏览器会自动打开GUI界面
3. 根据环境检测结果选择打包模式
4. 上传文件或填写信息
5. 点击开始重新打包
6. 下载生成的离线包

更多信息: https://github.com/langgenius/dify-plugin-daemon
EOF

    echo -e "${GREEN}✓ Windows应用程序创建完成: Windows-App/${NC}"
}

# 创建Linux AppImage (如果在Linux环境)
build_linux_appimage() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo -e "${YELLOW}构建Linux AppImage...${NC}"
        
        local app_name="DifyPluginRepackager"
        local appdir="$OUTPUT_DIR/$app_name.AppDir"
        
        mkdir -p "$appdir/usr/bin" "$appdir/usr/share/applications" "$appdir/usr/share/icons/hicolor/256x256/apps"
        
        # 构建Linux可执行文件
        go build -ldflags "-s -w -X main.version=1.0.0-desktop" -o "$appdir/usr/bin/$app_name" ./cmd/repackage-gui/
        go build -ldflags "-s -w -X main.version=1.0.0-desktop" -o "$appdir/usr/bin/repackage" ./cmd/repackage/
        
        # 复制必要文件
        cp "$REPACKAGE_DIR/plugin_repackaging.sh" "$appdir/usr/bin/"
        cp "$REPACKAGE_DIR"/dify-plugin-linux-* "$appdir/usr/bin/" 2>/dev/null || true
        
        # 设置权限
        chmod +x "$appdir/usr/bin"/*
        
        # 创建桌面文件
        cat > "$appdir/usr/share/applications/$app_name.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Dify Plugin Repackager
Comment=Dify插件离线打包工具
Exec=$app_name
Icon=$app_name
Categories=Development;Utility;
Terminal=false
StartupNotify=true
EOF

        # 创建AppRun
        cat > "$appdir/AppRun" << EOF
#!/bin/bash
SELF=\$(readlink -f "\$0")
HERE=\${SELF%/*}
export PATH="\${HERE}/usr/bin:\${PATH}"
cd "\${HERE}/usr/bin"
exec "\${HERE}/usr/bin/$app_name" "\$@"
EOF
        chmod +x "$appdir/AppRun"
        
        # 复制图标和桌面文件到根目录
        create_app_icon "$appdir"
        cp "$appdir/icon.svg" "$appdir/usr/share/icons/hicolor/256x256/apps/$app_name.svg"
        cp "$appdir/usr/share/applications/$app_name.desktop" "$appdir/"
        
        echo -e "${GREEN}✓ Linux AppImage目录创建完成: $app_name.AppDir${NC}"
        echo -e "${YELLOW}提示: 使用appimagetool可以打包成AppImage文件${NC}"
    fi
}

# 主构建流程
main() {
    # 根据当前系统构建对应的应用
    case "$OSTYPE" in
        darwin*)
            build_mac_app
            # 如果有交叉编译需求，也构建Windows版本
            build_windows_app
            ;;
        linux-gnu*)
            build_linux_appimage
            build_windows_app
            ;;
        msys*|cygwin*|mingw*)
            build_windows_app
            ;;
        *)
            echo -e "${YELLOW}构建所有平台版本...${NC}"
            build_mac_app
            build_windows_app
            build_linux_appimage
            ;;
    esac
    
    # 创建分发包
    echo -e "${YELLOW}创建分发包...${NC}"
    cd "$OUTPUT_DIR"
    
    # Mac DMG
    if [ -d "DifyPluginRepackager.app" ]; then
        if command -v hdiutil >/dev/null 2>&1; then
            echo -e "${YELLOW}创建Mac DMG镜像...${NC}"
            hdiutil create -size 200m -fs HFS+ -volname "Dify Plugin Repackager" "DifyPluginRepackager-Mac.dmg" >/dev/null 2>&1
            hdiutil attach "DifyPluginRepackager-Mac.dmg" -mountpoint "/tmp/dmg_mount" >/dev/null 2>&1
            cp -R "DifyPluginRepackager.app" "/tmp/dmg_mount/"
            ln -s /Applications "/tmp/dmg_mount/Applications"
            hdiutil detach "/tmp/dmg_mount" >/dev/null 2>&1
            hdiutil convert "DifyPluginRepackager-Mac.dmg" -format UDZO -o "DifyPluginRepackager-Mac-Final.dmg" >/dev/null 2>&1
            mv "DifyPluginRepackager-Mac-Final.dmg" "DifyPluginRepackager-Mac.dmg"
            echo -e "${GREEN}✓ Mac DMG创建完成${NC}"
        fi
    fi
    
    # Windows ZIP
    if [ -d "Windows-App" ]; then
        if command -v zip >/dev/null 2>&1; then
            zip -r "DifyPluginRepackager-Windows.zip" "Windows-App/" >/dev/null
            echo -e "${GREEN}✓ Windows ZIP创建完成${NC}"
        fi
    fi
    
    # Linux tar.gz
    if [ -d "DifyPluginRepackager.AppDir" ]; then
        tar -czf "DifyPluginRepackager-Linux.tar.gz" "DifyPluginRepackager.AppDir/"
        echo -e "${GREEN}✓ Linux tar.gz创建完成${NC}"
    fi
    
    cd "$PROJECT_ROOT"
}

# 执行主函数
main

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  桌面应用程序构建完成！${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}输出目录: $OUTPUT_DIR${NC}"
echo -e "${YELLOW}构建的应用程序:${NC}"
ls -la "$OUTPUT_DIR" | grep -E '\.(app|exe|dmg|zip|tar\.gz)$' || ls -la "$OUTPUT_DIR"

echo -e "\n${YELLOW}使用说明:${NC}"
echo -e "${GREEN}Mac:${NC} 双击 DifyPluginRepackager.app 或安装 DMG"
echo -e "${GREEN}Windows:${NC} 双击 DifyPluginRepackager.exe 或运行 install.bat"
echo -e "${GREEN}Linux:${NC} 运行 AppImage 或解压 tar.gz"

exit 0 