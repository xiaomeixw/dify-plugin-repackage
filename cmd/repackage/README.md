# Dify Plugin Repackaging Tool

Dify Plugin Repackaging Tool 是一个用于将 Dify 插件重新打包为离线可用版本的工具。该工具能够下载插件的所有依赖并重新打包，使得插件可以在没有互联网连接的环境中安装和使用。

## 1. 功能特点

- 支持处理本地 `.difypkg` 文件
- 支持从 Dify Marketplace 下载并重新打包插件
- 支持从 GitHub 下载并重新打包插件
- 自动检测当前环境并选择合适的执行方式：
  - 在 Docker 容器内直接执行
  - 在安装了 Docker 的环境中使用 dify-plugin-daemon 容器执行
  - 在本地环境中执行（需用户确认）
- 自动识别操作系统和硬件架构，使用对应版本的 `dify-plugin` 工具

如果想快速上手，请直接跳转到条目6体验

## 2. 安装

### 2.1 编译

使用提供的构建脚本可以轻松编译该工具：

```bash
./.script/build-repackage.sh
```

该脚本将：
1. 自动检测操作系统和架构
2. 编译适合您环境的二进制文件
3. 将文件输出到 `bin/` 目录
4. 创建名为 `repackage` 的符号链接指向该二进制文件
5. 复制必要的脚本文件和 `dify-plugin` 工具到 `bin/` 目录

### 2.2 依赖要求

- Go 1.23 或更高版本（仅编译时需要）
- Docker（可选，用于在隔离环境中执行）
- 在本地执行时需要：
  - Python 3.12
  - pip
  - unzip

## 3. 使用方法

### 3.1 处理本地文件

```bash
./bin/repackage local /path/to/your-plugin.difypkg
```

### 3.2 从 Dify Marketplace 下载并处理

```bash
./bin/repackage market [plugin author] [plugin name] [plugin version]
```

例如：
```bash
./bin/repackage market langgenius agent 0.0.9
```

### 3.3 从 GitHub 下载并处理

```bash
./bin/repackage github [Github repo] [Release title] [Assets name]
```

例如：
```bash
./bin/repackage github junjiem/dify-plugin-tools-dbquery 0.0.9 db_query.difypkg
./bin/repackage github junjiem/dify-plugin-tools-mcp_sse 0.2.0 mcp_sse.difypkg
```

## 4. 执行环境

该工具会根据当前环境自动选择最合适的执行方式：

### 4.1 Docker 容器内直接执行

如果工具检测到它正在 Docker 容器内运行，它会在当前容器内直接执行重新打包操作。

注意：
需要确保docker容器部署有go编译环境。
如果你所在容器没有go环境，你也不想部署。

则使用build-repackage-in-docker.sh文件即可

```bash
./.script/build-repackage-in-docker.sh local /path/to/your-plugin.difypkg
```

### 4.2 使用 dify-plugin-daemon 容器

如果工具检测到系统安装了 Docker 并且存在 dify-plugin-daemon 镜像或容器，它会：
- 找到一个可用的 dify-plugin-daemon 容器
- 将必要的文件复制到容器内
- 在容器内执行重新打包操作
- 将结果复制回本地目录

### 4.3 本地执行

如果以上两种方法都不可行，工具会询问用户是否希望在本地执行。如果用户确认，工具将在本地环境中执行重新打包操作。

## 5. 注意事项

- 请确保将适合您操作系统和架构的 `dify-plugin-*-5g` 文件放在 `cmd/repackage/` 目录下，构建脚本会自动将其复制到正确的位置。
- 在本地执行时可能需要安装额外的依赖，如 Python 包和系统工具。
- 处理大型插件或有大量依赖的插件时，可能需要较长时间下载和处理。

## 6. 快速开始

1. 编译工具：
   ```bash
   ./.script/build-repackage.sh
   ```

2. 重新打包本地插件：
   ```bash
   ./bin/repackage local ./my-plugin.difypkg
   ```

3. 查看输出：
   ```bash
   打包后的文件将被保存为 `my-plugin-platform-offline.difypkg`，可以在离线环境中使用。 
   platform参数对应的是编译时环境，也代表该离线插件包可以导入的平台环境，两者需要匹配。
   
   比如：perfxlab-ocr_tool_0.0.1-linux-arm64-offline.difypkg 代表该离线插件可以导入Linux arm64位环境中。
   所以导入前请务必知晓插件容器的平台环境。
   ```

## 7. 特殊功能

如果你的环境不适合本地编译，同时也没有dify-plugin-daemon镜像，你也不想部署。
则可以使用自定义镜像dify-plugin-repackage完成repackage的操作。

该镜像环境与dify-plugin-daemon一致。 

- GO版本Ver1.23.0，Python版本3.12
- 预装pip包，预装uv包，预装unzip包，预装dify-plugin包

   ```bash
   ./.script/build-repackage-creat-docker.sh run local /path/to/your-plugin.difypkg
   ```
  
## 8. 插件平台限制

- 在 .env 配置文件将 FORCE_VERIFYING_SIGNATURE 改为 false （Dify平台将允许安装所有未在 Dify Marketplace 上架（审核）的插件）
- 在 .env 配置文件将 PLUGIN_MAX_PACKAGE_SIZE 增大为 524288000 （Dify平台将允许安装 500M 大小以内的插件）
- 在 .env 配置文件将 NGINX_CLIENT_MAX_BODY_SIZE 增大为 500M （Nginx客户端将允许上传 500M 大小以内的内容）