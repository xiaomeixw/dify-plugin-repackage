package main

import (
	"bufio"
	"context"
	"embed"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"syscall"
	"time"
)

//go:embed static/*
var staticFiles embed.FS

//go:embed templates/*
var templateFiles embed.FS

type RepackageRequest struct {
	Mode       string `json:"mode"`       // "local", "market", "github"
	Execution  string `json:"execution"`  // "local", "docker", "new-docker"
	FilePath   string `json:"filePath"`   // for local mode
	Author     string `json:"author"`     // for market mode
	Name       string `json:"name"`       // for market mode
	Version    string `json:"version"`    // for market mode
	Repository string `json:"repository"` // for github mode
	Release    string `json:"release"`    // for github mode
	Asset      string `json:"asset"`      // for github mode
}

type RepackageResponse struct {
	Success bool   `json:"success"`
	Message string `json:"message"`
	Output  string `json:"output"`
	Error   string `json:"error"`
}

type ProgressUpdate struct {
	Stage   string `json:"stage"`
	Message string `json:"message"`
	Percent int    `json:"percent"`
}

type SystemCapabilities struct {
	DockerAvailable        bool     `json:"dockerAvailable"`
	DockerRunning          bool     `json:"dockerRunning"`
	PluginContainerRunning bool     `json:"pluginContainerRunning"`
	PluginContainers       []string `json:"pluginContainers"`
	PythonAvailable        bool     `json:"pythonAvailable"`
	PythonVersion          string   `json:"pythonVersion"`
	PipAvailable           bool     `json:"pipAvailable"`
	UnzipAvailable         bool     `json:"unzipAvailable"`
	NetworkAvailable       bool     `json:"networkAvailable"`
	RecommendedModes       []string `json:"recommendedModes"`
	DisabledModes          []string `json:"disabledModes"`
	WarningMessages        []string `json:"warningMessages"`
}

var (
	version   = "1.0.0"
	buildTime = ""
	gitCommit = ""
)

func main() {
	port := getPort()

	// 创建HTTP服务器
	mux := http.NewServeMux()

	// 静态文件服务
	staticFS, _ := fs.Sub(staticFiles, "static")
	mux.Handle("/static/", http.StripPrefix("/static/", http.FileServer(http.FS(staticFS))))

	// API路由
	mux.HandleFunc("/", handleIndex)
	mux.HandleFunc("/api/capabilities", handleCapabilities)
	mux.HandleFunc("/api/upload", handleUpload)
	mux.HandleFunc("/api/repackage", handleRepackage)
	mux.HandleFunc("/api/status", handleStatus)
	mux.HandleFunc("/api/download/", handleDownload)

	server := &http.Server{
		Addr:    fmt.Sprintf(":%d", port),
		Handler: mux,
	}

	// 启动服务器
	go func() {
		log.Printf("🚀 Dify Plugin Repackager GUI v%s", version)
		log.Printf("🌐 服务器启动在: http://localhost:%d", port)
		log.Printf("📱 请在浏览器中打开上述地址")

		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("服务器启动失败: %v", err)
		}
	}()

	// 自动打开浏览器
	time.Sleep(1 * time.Second)
	openBrowser(fmt.Sprintf("http://localhost:%d", port))

	// 在桌面应用模式下，显示系统托盘或保持运行
	if isDesktopMode() {
		log.Println("🚀 检测到桌面应用模式")
		runAsDesktopApp(server)
	} else {
		// 命令行模式，等待中断信号
		quit := make(chan os.Signal, 1)
		signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
		<-quit

		log.Println("正在关闭服务器...")
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if err := server.Shutdown(ctx); err != nil {
			log.Fatalf("服务器关闭失败: %v", err)
		}

		log.Println("服务器已关闭")
	}
}

func isDesktopMode() bool {
	// 检查是否作为桌面应用运行
	execPath, err := os.Executable()
	if err != nil {
		return false
	}

	// Mac应用程序包
	if runtime.GOOS == "darwin" && strings.Contains(execPath, ".app/Contents/MacOS/") {
		return true
	}

	// Windows桌面应用
	if runtime.GOOS == "windows" && !isConsoleMode() {
		return true
	}

	return false
}

func isConsoleMode() bool {
	// 在Windows上检查是否有控制台窗口
	if runtime.GOOS == "windows" {
		// 检查可执行文件名是否包含控制台标识
		execPath, err := os.Executable()
		if err != nil {
			return false
		}

		// 如果可执行文件在Windows-App目录中，则认为是桌面模式
		if strings.Contains(execPath, "Windows-App") {
			return false
		}

		// 其他情况，检查是否有命令行参数
		return len(os.Args) > 1
	}
	return true
}

func runAsDesktopApp(server *http.Server) {
	log.Println("🖥️ 桌面应用模式启动")

	// 桌面应用模式：保持运行直到用户主动退出
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	// 创建一个保持运行的ticker，防止应用被系统回收
	keepAlive := time.NewTicker(30 * time.Second)
	defer keepAlive.Stop()

	// 创建一个优雅关闭的通道
	done := make(chan bool, 1)

	go func() {
		select {
		case <-quit:
			log.Println("收到退出信号，正在关闭应用...")
		case <-time.After(24 * time.Hour): // 24小时后自动退出，防止无限运行
			log.Println("应用运行超时，自动退出...")
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if err := server.Shutdown(ctx); err != nil {
			log.Printf("服务器关闭失败: %v", err)
		}

		done <- true
	}()

	// 主循环：保持应用活跃状态
	go func() {
		for {
			select {
			case <-keepAlive.C:
				// 每30秒输出一次状态，保持应用活跃
				log.Printf("📱 应用运行中... 浏览器地址: http://localhost:%d", getPort())
			case <-done:
				return
			}
		}
	}()

	log.Printf("🎯 应用已启动，请使用浏览器访问: http://localhost:%d", getPort())
	log.Println("💡 要退出应用，请按 Cmd+Q 或关闭此窗口")

	// 等待关闭信号
	<-done
	log.Println("✅ 应用已安全关闭")
}

func getPort() int {
	if port := os.Getenv("PORT"); port != "" {
		if p, err := strconv.Atoi(port); err == nil {
			return p
		}
	}
	return 18080
}

func openBrowser(url string) {
	var cmd string
	var args []string

	switch runtime.GOOS {
	case "windows":
		cmd = "cmd"
		args = []string{"/c", "start"}
	case "darwin":
		cmd = "open"
	default: // "linux", "freebsd", "openbsd", "netbsd"
		cmd = "xdg-open"
	}
	args = append(args, url)

	if err := exec.Command(cmd, args...).Start(); err != nil {
		log.Printf("无法自动打开浏览器: %v", err)
	}
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	indexHTML, err := templateFiles.ReadFile("templates/index.html")
	if err != nil {
		http.Error(w, "无法加载页面", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write(indexHTML)
}

func handleUpload(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "只支持POST请求", http.StatusMethodNotAllowed)
		return
	}

	// 解析上传的文件
	err := r.ParseMultipartForm(100 << 20) // 100MB max
	if err != nil {
		respondJSON(w, RepackageResponse{
			Success: false,
			Error:   "文件解析失败: " + err.Error(),
		})
		return
	}

	file, handler, err := r.FormFile("file")
	if err != nil {
		respondJSON(w, RepackageResponse{
			Success: false,
			Error:   "获取文件失败: " + err.Error(),
		})
		return
	}
	defer file.Close()

	// 验证文件扩展名
	if !strings.HasSuffix(handler.Filename, ".difypkg") {
		respondJSON(w, RepackageResponse{
			Success: false,
			Error:   "只支持 .difypkg 文件",
		})
		return
	}

	// 创建临时目录
	uploadDir := filepath.Join(os.TempDir(), "dify-repackager-uploads")
	os.MkdirAll(uploadDir, 0755)

	// 保存文件
	filePath := filepath.Join(uploadDir, handler.Filename)
	dst, err := os.Create(filePath)
	if err != nil {
		respondJSON(w, RepackageResponse{
			Success: false,
			Error:   "保存文件失败: " + err.Error(),
		})
		return
	}
	defer dst.Close()

	_, err = io.Copy(dst, file)
	if err != nil {
		respondJSON(w, RepackageResponse{
			Success: false,
			Error:   "保存文件失败: " + err.Error(),
		})
		return
	}

	respondJSON(w, RepackageResponse{
		Success: true,
		Message: "文件上传成功",
		Output:  filePath,
	})
}

func handleRepackage(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, "只支持POST请求", http.StatusMethodNotAllowed)
		return
	}

	var req RepackageRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondJSON(w, RepackageResponse{
			Success: false,
			Error:   "请求解析失败: " + err.Error(),
		})
		return
	}

	// 执行重新打包
	result := executeRepackaging(req)
	respondJSON(w, result)
}

func handleStatus(w http.ResponseWriter, r *http.Request) {
	// 这里可以返回当前处理状态
	respondJSON(w, map[string]interface{}{
		"status":  "ready",
		"version": version,
	})
}

func handleDownload(w http.ResponseWriter, r *http.Request) {
	// 从URL路径中获取文件名
	fileName := strings.TrimPrefix(r.URL.Path, "/api/download/")
	if fileName == "" {
		http.Error(w, "文件名不能为空", http.StatusBadRequest)
		return
	}

	// 构建文件路径（安全检查）
	outputDir := filepath.Join(os.TempDir(), "dify-repackager-output")
	filePath := filepath.Join(outputDir, fileName)

	// 检查文件是否存在
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		http.Error(w, "文件不存在", http.StatusNotFound)
		return
	}

	// 设置下载头
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%s", fileName))
	w.Header().Set("Content-Type", "application/octet-stream")

	// 发送文件
	http.ServeFile(w, r, filePath)
}

func executeRepackaging(req RepackageRequest) RepackageResponse {
	// 创建输出目录
	outputDir := filepath.Join(os.TempDir(), "dify-repackager-output")
	os.MkdirAll(outputDir, 0755)

	// 构建命令参数
	var args []string
	switch req.Mode {
	case "local":
		if req.FilePath == "" {
			return RepackageResponse{
				Success: false,
				Error:   "本地模式需要指定文件路径",
			}
		}
		args = []string{"local", req.FilePath}

	case "market":
		if req.Author == "" || req.Name == "" || req.Version == "" {
			return RepackageResponse{
				Success: false,
				Error:   "市场模式需要指定作者、名称和版本",
			}
		}
		args = []string{"market", req.Author, req.Name, req.Version}

	case "github":
		if req.Repository == "" || req.Release == "" || req.Asset == "" {
			return RepackageResponse{
				Success: false,
				Error:   "GitHub模式需要指定仓库、发布版本和资源名称",
			}
		}
		args = []string{"github", req.Repository, req.Release, req.Asset}

	default:
		return RepackageResponse{
			Success: false,
			Error:   "不支持的模式: " + req.Mode,
		}
	}

	// 查找repackage可执行文件
	repackagePath := findRepackageExecutable()
	if repackagePath == "" {
		return RepackageResponse{
			Success: false,
			Error:   "找不到repackage可执行文件",
		}
	}

	// 执行命令
	cmd := exec.Command(repackagePath, args...)
	cmd.Dir = outputDir

	// 根据用户选择的执行环境设置环境变量
	cmd.Env = os.Environ()
	switch req.Execution {
	case "local":
		// 强制本地执行
		cmd.Env = append(cmd.Env, "FORCE_LOCAL_EXECUTION=true")
		log.Printf("🖥️ 用户选择本地执行环境")
	case "docker":
		// 优先使用Docker（默认行为）
		log.Printf("🐳 用户选择Docker容器执行环境")
	case "new-docker":
		// 创建新Docker环境（暂时使用现有Docker逻辑）
		log.Printf("🆕 用户选择新建Docker执行环境")
	default:
		// 默认行为：自动检测
		log.Printf("🔍 自动检测执行环境")
	}

	// 启动命令并获取实时输出
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return RepackageResponse{
			Success: false,
			Error:   fmt.Sprintf("无法获取输出管道: %v", err),
		}
	}

	stderr, err := cmd.StderrPipe()
	if err != nil {
		return RepackageResponse{
			Success: false,
			Error:   fmt.Sprintf("无法获取错误管道: %v", err),
		}
	}

	if err := cmd.Start(); err != nil {
		return RepackageResponse{
			Success: false,
			Error:   fmt.Sprintf("无法启动命令: %v", err),
		}
	}

	// 收集输出
	var outputBuffer strings.Builder

	// 读取stdout
	go func() {
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			line := scanner.Text()
			outputBuffer.WriteString(line + "\n")
			log.Printf("📋 CLI输出: %s", line)
		}
	}()

	// 读取stderr
	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			line := scanner.Text()
			outputBuffer.WriteString(line + "\n")
			log.Printf("⚠️ CLI错误: %s", line)
		}
	}()

	// 等待命令完成
	err = cmd.Wait()
	output := outputBuffer.String()

	if err != nil {
		return RepackageResponse{
			Success: false,
			Error:   fmt.Sprintf("执行失败: %v", err),
			Output:  output,
		}
	}

	// 查找生成的文件
	outputFiles := findOutputFiles(outputDir)

	return RepackageResponse{
		Success: true,
		Message: "重新打包成功",
		Output:  string(output) + "\n\n生成的文件: " + strings.Join(outputFiles, ", "),
	}
}

func findRepackageExecutable() string {
	// 获取当前可执行文件路径
	execPath, err := os.Executable()
	if err != nil {
		log.Printf("无法获取可执行文件路径: %v", err)
	}

	var possiblePaths []string

	// Mac应用程序包内的Resources目录
	if runtime.GOOS == "darwin" && strings.Contains(execPath, ".app/Contents/MacOS/") {
		appContentsDir := filepath.Dir(filepath.Dir(execPath)) // 从MacOS目录回到Contents目录
		resourcesDir := filepath.Join(appContentsDir, "Resources")
		possiblePaths = append(possiblePaths, filepath.Join(resourcesDir, "repackage"))
		log.Printf("🔍 Mac应用程序模式，Resources目录: %s", resourcesDir)
	}

	// 添加其他可能的路径
	possiblePaths = append(possiblePaths, []string{
		"./repackage",
		"../repackage",
		"./bin/repackage",
		"./dist-simple/repackage",
		"./dist-gui/repackage",
		"./dist-desktop/repackage",
	}...)

	// 在Windows上添加.exe扩展名
	if runtime.GOOS == "windows" {
		for i, path := range possiblePaths {
			possiblePaths[i] = path + ".exe"
		}
	}

	log.Printf("🔍 搜索repackage可执行文件，路径列表:")
	for _, path := range possiblePaths {
		log.Printf("  - 检查: %s", path)
		if _, err := os.Stat(path); err == nil {
			absPath, _ := filepath.Abs(path)
			log.Printf("✅ 找到repackage: %s", absPath)
			return absPath
		}
	}

	// 尝试从PATH中查找
	if path, err := exec.LookPath("repackage"); err == nil {
		log.Printf("✅ 从PATH找到repackage: %s", path)
		return path
	}

	log.Printf("❌ 未找到repackage可执行文件")
	return ""
}

func findOutputFiles(dir string) []string {
	var files []string

	filepath.Walk(dir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return nil
		}

		if !info.IsDir() && strings.HasSuffix(info.Name(), "-offline.difypkg") {
			files = append(files, info.Name())
		}

		return nil
	})

	return files
}

func handleCapabilities(w http.ResponseWriter, r *http.Request) {
	capabilities := detectSystemCapabilities()
	respondJSON(w, capabilities)
}

func detectSystemCapabilities() SystemCapabilities {
	capabilities := SystemCapabilities{
		RecommendedModes: []string{},
		DisabledModes:    []string{},
		WarningMessages:  []string{},
	}

	// 检测Docker
	capabilities.DockerAvailable = isDockerInstalled()
	if capabilities.DockerAvailable {
		capabilities.DockerRunning = isDockerRunning()
		// 检测插件容器是否运行
		capabilities.PluginContainers = getPluginContainers()
		capabilities.PluginContainerRunning = len(capabilities.PluginContainers) > 0
	}

	// 检测Python
	capabilities.PythonAvailable, capabilities.PythonVersion = isPythonAvailable()

	// 检测pip
	capabilities.PipAvailable = isPipAvailable()

	// 检测unzip
	capabilities.UnzipAvailable = isUnzipAvailable()

	// 检测网络连接
	capabilities.NetworkAvailable = isNetworkAvailable()

	// 根据检测结果推荐模式
	if capabilities.DockerAvailable && capabilities.DockerRunning {
		capabilities.RecommendedModes = append(capabilities.RecommendedModes, "local", "market", "github")
		capabilities.WarningMessages = append(capabilities.WarningMessages, "✅ Docker环境可用，推荐使用所有模式")
	} else if capabilities.PythonAvailable && capabilities.PipAvailable && capabilities.UnzipAvailable {
		capabilities.RecommendedModes = append(capabilities.RecommendedModes, "local")
		if capabilities.NetworkAvailable {
			capabilities.RecommendedModes = append(capabilities.RecommendedModes, "market", "github")
			capabilities.WarningMessages = append(capabilities.WarningMessages, "⚠️ 本地Python环境可用，但建议安装Docker以获得更好的兼容性")
		} else {
			capabilities.DisabledModes = append(capabilities.DisabledModes, "market", "github")
			capabilities.WarningMessages = append(capabilities.WarningMessages, "⚠️ 网络不可用，只能使用本地文件模式")
		}
	} else {
		// 环境不足，只推荐Docker
		capabilities.DisabledModes = append(capabilities.DisabledModes, "market", "github")
		if !capabilities.PythonAvailable {
			capabilities.WarningMessages = append(capabilities.WarningMessages, "❌ 未检测到Python 3.12+，建议安装Docker")
		}
		if !capabilities.PipAvailable {
			capabilities.WarningMessages = append(capabilities.WarningMessages, "❌ 未检测到pip包管理器")
		}
		if !capabilities.UnzipAvailable {
			capabilities.WarningMessages = append(capabilities.WarningMessages, "❌ 未检测到unzip工具")
		}

		if capabilities.DockerAvailable {
			capabilities.WarningMessages = append(capabilities.WarningMessages, "💡 检测到Docker已安装，请启动Docker服务")
		} else {
			capabilities.WarningMessages = append(capabilities.WarningMessages, "💡 建议安装Docker以获得最佳体验")
		}
	}

	return capabilities
}

// 各平台最常见路径，按优先级排序
var dockerPaths = func() []string {
	switch runtime.GOOS {
	case "windows":
		return []string{
			`C:\Program Files\Docker\Docker\resources\bin\docker.exe`,
			`C:\ProgramData\DockerDesktop\version-bin\docker.exe`,
			`C:\Windows\System32\docker.exe`,
		}
	case "darwin": // macOS
		return []string{
			"/usr/local/bin/docker",    // Intel Homebrew
			"/opt/homebrew/bin/docker", // Apple Silicon Homebrew
			"/usr/bin/docker",          // 官方 .pkg
		}
	default: // Linux 等
		return []string{
			"/usr/bin/docker",
			"/usr/local/bin/docker",
			"/snap/bin/docker", // Ubuntu snap
		}
	}
}()

// 返回 docker 可执行文件的绝对路径；找不到返回空串。
func dockerBinary() string {
	// 1) 试常用绝对路径
	for _, p := range dockerPaths {
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	// 2) 兜底用 PATH 搜索
	if p, err := exec.LookPath("docker"); err == nil {
		return p
	}
	return ""
}

// IsDockerInstalled 仅判断 CLI 是否存在。
func isDockerInstalled() bool { return dockerBinary() != "" }

// IsDockerRunning 判断 Docker Engine（守护进程）是否已响应。
func isDockerRunning() bool {
	bin := dockerBinary()
	if bin == "" {
		return false
	}
	cmd := exec.Command(bin, "info")
	return cmd.Run() == nil
}

func getPluginContainers() []string {
	bin := dockerBinary()
	if bin == "" {
		fmt.Println("Docker CLI not found")
		return []string{}
	}

	cmd := exec.Command(bin, "ps", "--format", "{{.Names}}")
	output, err := cmd.Output()
	if err != nil {
		fmt.Printf("Docker ps error: %v\n", err)
		return []string{}
	}

	containers := strings.Split(strings.TrimSpace(string(output)), "\n")
	fmt.Printf("Detected containers: %v\n", containers)

	var pluginContainers []string
	for _, c := range containers {
		if strings.Contains(strings.ToLower(c), "plugin") {
			pluginContainers = append(pluginContainers, c)
		}
	}
	fmt.Printf("Plugin containers found: %v\n", pluginContainers)
	return pluginContainers
}

func isPythonAvailable() (bool, string) {
	// 尝试检测Python 3.12+
	pythonCommands := []string{"python3.12", "python3", "python"}

	for _, pythonCmd := range pythonCommands {
		cmd := exec.Command(pythonCmd, "--version")
		output, err := cmd.Output()
		if err == nil {
			version := strings.TrimSpace(string(output))
			// 简单版本检查
			if strings.Contains(version, "Python 3.") {
				versionParts := strings.Split(version, ".")
				if len(versionParts) >= 2 {
					// 检查是否为3.12+
					if strings.Contains(versionParts[1], "12") ||
						strings.Contains(versionParts[1], "13") ||
						strings.Contains(versionParts[1], "14") {
						return true, version
					}
				}
				return true, version // 至少有Python 3.x
			}
		}
	}

	return false, ""
}

func isPipAvailable() bool {
	pipCommands := []string{"pip3", "pip"}

	for _, pipCmd := range pipCommands {
		cmd := exec.Command(pipCmd, "--version")
		if cmd.Run() == nil {
			return true
		}
	}

	return false
}

func isUnzipAvailable() bool {
	cmd := exec.Command("unzip", "-v")
	return cmd.Run() == nil
}

func isNetworkAvailable() bool {
	const maxTries = 3

	args := []string{"-c", "1", "-W", "1000", "pypi.org"}
	if runtime.GOOS == "windows" {
		args = []string{"-n", "1", "-w", "1000", "pypi.org"}
	}

	for i := 0; i < maxTries; i++ {
		cmd := exec.Command("ping", args...)
		if cmd.Run() == nil {
			return true // 有一次通就行
		}
	}
	return false // 3 次全失败
}

func respondJSON(w http.ResponseWriter, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(data)
}
