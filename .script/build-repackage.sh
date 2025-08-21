#!/bin/bash

# 设置颜色变量
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 获取脚本所在目录和项目根目录
SCRIPT_DIR=$(dirname "$0")
cd "$SCRIPT_DIR"
PROJECT_ROOT=$(cd .. && pwd)

# 设置输出目录和源代码目录
OUTPUT_DIR="$PROJECT_ROOT/bin"
SOURCE_DIR="$PROJECT_ROOT/cmd/repackage"

# 确保输出目录存在
mkdir -p "$OUTPUT_DIR"

# 根据操作系统和架构设置构建目标
OS_TYPE=$(uname | tr '[:upper:]' '[:lower:]')
ARCH_NAME=$(uname -m)

if [[ "$OS_TYPE" == "darwin" ]]; then
  if [[ "$ARCH_NAME" == "arm64" ]]; then
    OUTPUT_NAME="$OUTPUT_DIR/repackage-darwin-arm64"
    DIFY_PLUGIN_NAME="dify-plugin-darwin-arm64-5g"
  else
    OUTPUT_NAME="$OUTPUT_DIR/repackage-darwin-amd64"
    DIFY_PLUGIN_NAME="dify-plugin-darwin-amd64-5g"
  fi
elif [[ "$OS_TYPE" == "linux" ]]; then
  if [[ "$ARCH_NAME" == "aarch64" || "$ARCH_NAME" == "arm64" ]]; then
    OUTPUT_NAME="$OUTPUT_DIR/repackage-linux-arm64"
    DIFY_PLUGIN_NAME="dify-plugin-linux-arm64-5g"
  else
    OUTPUT_NAME="$OUTPUT_DIR/repackage-linux-amd64"
    DIFY_PLUGIN_NAME="dify-plugin-linux-amd64-5g"
  fi
else
  echo -e "${RED}不支持的操作系统: $OS_TYPE${NC}"
  exit 1
fi

# 创建符号链接
SYMLINK_NAME="$OUTPUT_DIR/repackage"

# 编译repackage工具
echo -e "${YELLOW}正在编译repackage工具...${NC}"
cd "$PROJECT_ROOT"
go build -o "$OUTPUT_NAME" ./cmd/repackage/

if [ $? -ne 0 ]; then
  echo -e "${RED}编译失败!${NC}"
  exit 1
fi

# 创建符号链接到输出文件
cd "$OUTPUT_DIR"
ln -sf "$(basename $OUTPUT_NAME)" "repackage"

# 确保plugin_repackaging.sh脚本在正确位置并具有执行权限
if [ ! -f "$OUTPUT_DIR/plugin_repackaging.sh" ]; then
  echo -e "${YELLOW}正在复制plugin_repackaging.sh到$OUTPUT_DIR...${NC}"
  cp "$SOURCE_DIR/plugin_repackaging.sh" "$OUTPUT_DIR/"
fi

# 复制所有架构的dify-plugin文件到bin目录
echo -e "${YELLOW}正在复制所有架构的dify-plugin文件到$OUTPUT_DIR...${NC}"

# 定义所有需要复制的dify-plugin文件
PLUGIN_FILES=(
  "dify-plugin-darwin-arm64-5g"
  "dify-plugin-darwin-amd64-5g"
  "dify-plugin-linux-arm64-5g"
  "dify-plugin-linux-amd64-5g"
)

# 复制每一个插件文件
for plugin in "${PLUGIN_FILES[@]}"; do
  SOURCE_PATH="$SOURCE_DIR/$plugin"
  DEST_PATH="$OUTPUT_DIR/$plugin"
  
  if [ -f "$SOURCE_PATH" ]; then
    echo -e "${YELLOW}复制 $plugin 到 $OUTPUT_DIR...${NC}"
    cp "$SOURCE_PATH" "$DEST_PATH"
    chmod +x "$DEST_PATH"
  else
    echo -e "${YELLOW}警告: 在 $SOURCE_PATH 找不到 $plugin 文件${NC}"
  fi
done

# 确保当前架构的插件文件可用
if [ ! -f "$OUTPUT_DIR/$DIFY_PLUGIN_NAME" ]; then
  echo -e "${RED}警告: 找不到当前架构的插件文件: $DIFY_PLUGIN_NAME!${NC}"
  echo -e "${YELLOW}请确保将对应版本的dify-plugin文件放在 cmd/repackage/ 目录下${NC}"
fi

chmod +x "$OUTPUT_DIR/plugin_repackaging.sh"

echo -e "${GREEN}编译成功!${NC}"
echo -e "${YELLOW}可执行文件: $OUTPUT_NAME${NC}"
echo -e "${YELLOW}符号链接: $SYMLINK_NAME${NC}"

# 根据传入的参数决定是否直接运行
if [ $# -gt 0 ]; then
  echo -e "${YELLOW}正在运行 repackage $@${NC}"
  "$OUTPUT_NAME" "$@"
else
  # 显示用法信息
  echo -e "${YELLOW}用法:${NC}"
  echo -e "${GREEN}./.script/build-repackage.sh${NC} - 仅编译repackage工具"
  echo -e "${GREEN}./.script/build-repackage.sh local <difypkg文件路径>${NC} - 编译并重新打包本地插件"
  echo -e "${GREEN}./.script/build-repackage.sh market <插件作者> <插件名称> <插件版本>${NC} - 编译并从市场下载重新打包"
  echo -e "${GREEN}./.script/build-repackage.sh github <Github仓库> <发布标题> <资源名称>${NC} - 编译并从Github下载重新打包"
fi

exit 0
