// 全局变量
let currentMode = 'local';
let currentExecution = 'docker';
let uploadedFilePath = '';
let currentDownloadFile = '';
let systemCapabilities = null;

// DOM 元素
const elements = {
    modeRadios: document.querySelectorAll('input[name="mode"]'),
    modeForms: document.querySelectorAll('.mode-form'),
    fileInput: document.getElementById('file-input'),
    fileDropArea: document.getElementById('file-drop-area'),
    fileInfo: document.getElementById('file-info'),
    fileName: document.getElementById('file-name'),
    fileSize: document.getElementById('file-size'),
    repackageBtn: document.getElementById('repackage-btn'),
    progressSection: document.getElementById('progress-section'),
    progressBar: document.getElementById('progress-bar'),
    progressStage: document.getElementById('progress-stage'),
    progressLog: document.getElementById('progress-log'),
    resultSection: document.getElementById('result-section'),
    resultSuccess: document.getElementById('result-success'),
    resultError: document.getElementById('result-error'),
    resultFiles: document.getElementById('result-files'),
    errorMessage: document.getElementById('error-message'),
    errorDetails: document.getElementById('error-details'),
    downloadBtn: document.getElementById('download-btn'),
    newTaskBtn: document.getElementById('new-task-btn'),
    retryBtn: document.getElementById('retry-btn'),
    // 表单输入
    marketAuthor: document.getElementById('market-author'),
    marketName: document.getElementById('market-name'),
    marketVersion: document.getElementById('market-version'),
    githubRepo: document.getElementById('github-repo'),
    githubRelease: document.getElementById('github-release'),
    githubAsset: document.getElementById('github-asset')
};

// 初始化
document.addEventListener('DOMContentLoaded', function() {
    initializeEventListeners();
    loadSystemCapabilities();
});

// 事件监听器
function initializeEventListeners() {
    // 执行环境切换
    document.querySelectorAll('input[name="execution"]').forEach(radio => {
        radio.addEventListener('change', function() {
            if (this.checked) {
                switchExecution(this.value);
            }
        });
    });

    // 模式切换
    elements.modeRadios.forEach(radio => {
        radio.addEventListener('change', function() {
            if (this.checked) {
                switchMode(this.value);
            }
        });
    });

    // 文件上传
    elements.fileDropArea.addEventListener('click', () => elements.fileInput.click());
    elements.fileDropArea.addEventListener('dragover', handleDragOver);
    elements.fileDropArea.addEventListener('dragleave', handleDragLeave);
    elements.fileDropArea.addEventListener('drop', handleFileDrop);
    elements.fileInput.addEventListener('change', handleFileSelect);

    // 按钮事件
    elements.repackageBtn.addEventListener('click', startRepackaging);
    elements.downloadBtn.addEventListener('click', downloadResult);
    elements.newTaskBtn.addEventListener('click', resetForm);
    elements.retryBtn.addEventListener('click', startRepackaging);

    // 表单验证
    [elements.marketAuthor, elements.marketName, elements.marketVersion].forEach(input => {
        input.addEventListener('input', validateMarketForm);
    });

    [elements.githubRepo, elements.githubRelease, elements.githubAsset].forEach(input => {
        input.addEventListener('input', validateGithubForm);
    });
}

// 执行环境切换
function switchExecution(execution) {
    currentExecution = execution;
    console.log('切换执行环境到:', execution);
    
    // 更新执行环境信息
    updateExecutionInfo(execution);
}

// 更新执行环境信息
function updateExecutionInfo(execution) {
    // 根据执行环境显示相应的提示信息
    let infoHtml = '';
    switch(execution) {
        case 'local':
            infoHtml = '<i class="bi bi-info-circle text-info"></i> 将使用本地Python环境进行打包';
            break;
        case 'docker':
            infoHtml = '<i class="bi bi-info-circle text-info"></i> 将使用现有Docker容器进行打包';
            break;
        case 'new-docker':
            infoHtml = '<i class="bi bi-info-circle text-info"></i> 将创建新的Docker环境进行打包';
            break;
    }
    
    // 在界面上显示执行环境信息
    console.log('执行环境信息:', infoHtml);
}

// 模式切换
function switchMode(mode) {
    currentMode = mode;
    
    // 隐藏所有表单
    elements.modeForms.forEach(form => {
        form.style.display = 'none';
    });
    
    // 显示选中的表单
    const targetForm = document.getElementById(mode + '-form');
    if (targetForm) {
        targetForm.style.display = 'block';
        targetForm.classList.add('fade-in');
    }
    
    // 重置状态
    resetForm();
}

// 文件拖拽处理
function handleDragOver(e) {
    e.preventDefault();
    e.stopPropagation();
    elements.fileDropArea.classList.add('dragover');
}

function handleDragLeave(e) {
    e.preventDefault();
    e.stopPropagation();
    elements.fileDropArea.classList.remove('dragover');
}

function handleFileDrop(e) {
    e.preventDefault();
    e.stopPropagation();
    elements.fileDropArea.classList.remove('dragover');
    
    const files = e.dataTransfer.files;
    if (files.length > 0) {
        handleFile(files[0]);
    }
}

function handleFileSelect(e) {
    const file = e.target.files[0];
    if (file) {
        handleFile(file);
    }
}

// 文件处理
function handleFile(file) {
    // 验证文件类型
    if (!file.name.endsWith('.difypkg')) {
        showError('只支持 .difypkg 格式的文件');
        return;
    }
    
    // 验证文件大小 (100MB)
    if (file.size > 100 * 1024 * 1024) {
        showError('文件大小不能超过 100MB');
        return;
    }
    
    // 显示文件信息
    elements.fileName.textContent = file.name;
    elements.fileSize.textContent = `(${formatFileSize(file.size)})`;
    elements.fileInfo.style.display = 'block';
    elements.fileInfo.classList.add('fade-in');
    
    // 上传文件
    uploadFile(file);
}

// 文件上传
function uploadFile(file) {
    const formData = new FormData();
    formData.append('file', file);
    
    showProgress('上传文件中...', 10);
    
    fetch('/api/upload', {
        method: 'POST',
        body: formData
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            uploadedFilePath = data.output;
            updateProgress('文件上传成功', 20);
            setTimeout(() => hideProgress(), 1000);
        } else {
            throw new Error(data.error || '文件上传失败');
        }
    })
    .catch(error => {
        showError('文件上传失败: ' + error.message);
        hideProgress();
    });
}

// 开始重新打包
function startRepackaging() {
    console.log('🚀 开始重新打包...');
    
    if (!validateForm()) {
        console.log('❌ 表单验证失败');
        return;
    }
    
    console.log('✅ 表单验证通过');
    
    // 清除之前的结果和错误信息
    hideResults();
    hideError();
    
    // 构建请求数据
    const requestData = buildRequestData();
    
    // 显示进度
    showProgress('开始处理...', 0);
    elements.repackageBtn.disabled = true;
    
    // 发送请求
    fetch('/api/repackage', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(requestData)
    })
    .then(response => response.json())
    .then(data => {
        elements.repackageBtn.disabled = false;
        hideProgress();
        
        if (data.success) {
            showSuccess(data.message, data.output);
        } else {
            showError(data.error || '处理失败', data.output);
        }
    })
    .catch(error => {
        elements.repackageBtn.disabled = false;
        hideProgress();
        showError('请求失败: ' + error.message);
    });
}

// 构建请求数据
function buildRequestData() {
    const data = { 
        mode: currentMode,
        execution: currentExecution
    };
    
    switch (currentMode) {
        case 'local':
            data.filePath = uploadedFilePath;
            break;
        case 'market':
            data.author = elements.marketAuthor.value.trim();
            data.name = elements.marketName.value.trim();
            data.version = elements.marketVersion.value.trim();
            break;
        case 'github':
            data.repository = elements.githubRepo.value.trim();
            data.release = elements.githubRelease.value.trim();
            data.asset = elements.githubAsset.value.trim();
            break;
    }
    
    return data;
}

// 表单验证
function validateForm() {
    switch (currentMode) {
        case 'local':
            if (!uploadedFilePath) {
                showError('请先上传 .difypkg 文件');
                return false;
            }
            return true;
        case 'market':
            return validateMarketForm();
        case 'github':
            return validateGithubForm();
        default:
            return false;
    }
}

function validateMarketForm() {
    const author = elements.marketAuthor.value.trim();
    const name = elements.marketName.value.trim();
    const version = elements.marketVersion.value.trim();
    
    let isValid = true;
    
    if (!author) {
        setFieldError(elements.marketAuthor, '请输入插件作者');
        isValid = false;
    } else {
        setFieldSuccess(elements.marketAuthor);
    }
    
    if (!name) {
        setFieldError(elements.marketName, '请输入插件名称');
        isValid = false;
    } else {
        setFieldSuccess(elements.marketName);
    }
    
    if (!version) {
        setFieldError(elements.marketVersion, '请输入版本号');
        isValid = false;
    } else {
        setFieldSuccess(elements.marketVersion);
    }
    
    return isValid;
}

function validateGithubForm() {
    const repo = elements.githubRepo.value.trim();
    const release = elements.githubRelease.value.trim();
    const asset = elements.githubAsset.value.trim();
    
    let isValid = true;
    
    if (!repo) {
        setFieldError(elements.githubRepo, '请输入GitHub仓库');
        isValid = false;
    } else if (!repo.includes('/')) {
        setFieldError(elements.githubRepo, '仓库格式应为: owner/repository');
        isValid = false;
    } else {
        setFieldSuccess(elements.githubRepo);
    }
    
    if (!release) {
        setFieldError(elements.githubRelease, '请输入发布版本');
        isValid = false;
    } else {
        setFieldSuccess(elements.githubRelease);
    }
    
    if (!asset) {
        setFieldError(elements.githubAsset, '请输入资源文件名');
        isValid = false;
    } else if (!asset.endsWith('.difypkg')) {
        setFieldError(elements.githubAsset, '资源文件必须是 .difypkg 格式');
        isValid = false;
    } else {
        setFieldSuccess(elements.githubAsset);
    }
    
    return isValid;
}

// 字段验证状态
function setFieldError(field, message) {
    field.classList.remove('is-valid');
    field.classList.add('is-invalid');
    
    // 移除旧的错误信息
    const oldFeedback = field.parentNode.querySelector('.invalid-feedback');
    if (oldFeedback) {
        oldFeedback.remove();
    }
    
    // 添加错误信息
    const feedback = document.createElement('div');
    feedback.className = 'invalid-feedback';
    feedback.textContent = message;
    field.parentNode.appendChild(feedback);
}

function setFieldSuccess(field) {
    field.classList.remove('is-invalid');
    field.classList.add('is-valid');
    
    // 移除错误信息
    const feedback = field.parentNode.querySelector('.invalid-feedback');
    if (feedback) {
        feedback.remove();
    }
}

// 进度显示
function showProgress(stage, percent) {
    elements.progressSection.style.display = 'block';
    elements.progressSection.classList.add('fade-in');
    updateProgress(stage, percent);
}

function updateProgress(stage, percent) {
    elements.progressStage.textContent = stage;
    elements.progressBar.style.width = percent + '%';
    elements.progressBar.setAttribute('aria-valuenow', percent);
    
    // 添加日志
    if (stage && stage !== elements.progressStage.textContent) {
        addLog(stage);
    }
}

function hideProgress() {
    elements.progressSection.style.display = 'none';
    elements.progressLog.textContent = '';
}

function hideResults() {
    elements.resultSection.style.display = 'none';
    elements.resultSuccess.style.display = 'none';
    elements.resultError.style.display = 'none';
}

function hideError() {
    elements.resultError.style.display = 'none';
}

function addLog(message) {
    const timestamp = new Date().toLocaleTimeString();
    elements.progressLog.textContent += `[${timestamp}] ${message}\n`;
    elements.progressLog.scrollTop = elements.progressLog.scrollHeight;
}

// 结果显示
function showSuccess(message, output) {
    elements.resultSection.style.display = 'block';
    elements.resultSection.classList.add('fade-in');
    elements.resultSuccess.style.display = 'block';
    elements.resultError.style.display = 'none';
    
    // 解析输出中的文件名
    const files = parseOutputFiles(output);
    if (files.length > 0) {
        currentDownloadFile = files[0];
        elements.resultFiles.innerHTML = files.map(file => 
            `<div class="mb-1"><i class="bi bi-file-earmark-zip"></i> ${file}</div>`
        ).join('');
    }
    
    // 显示完整输出
    addLog('处理完成');
    addLog(output);
}

function showError(message, details = '') {
    elements.resultSection.style.display = 'block';
    elements.resultSection.classList.add('fade-in');
    elements.resultSuccess.style.display = 'none';
    elements.resultError.style.display = 'block';
    
    elements.errorMessage.textContent = message;
    elements.errorDetails.textContent = details;
    
    addLog('处理失败: ' + message);
    if (details) {
        addLog(details);
    }
}

// 解析输出文件
function parseOutputFiles(output) {
    const files = [];
    const lines = output.split('\n');
    
    for (const line of lines) {
        if (line.includes('-offline.difypkg')) {
            const match = line.match(/([^\/\s]+?-offline\.difypkg)/);
            if (match) {
                files.push(match[1]);
            }
        }
    }
    
    return files;
}

// 下载结果
function downloadResult() {
    if (currentDownloadFile) {
        const link = document.createElement('a');
        link.href = '/api/download/' + encodeURIComponent(currentDownloadFile);
        link.download = currentDownloadFile;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }
}

// 重置表单
function resetForm() {
    // 隐藏结果和进度
    elements.progressSection.style.display = 'none';
    elements.resultSection.style.display = 'none';
    elements.fileInfo.style.display = 'none';
    
    // 清空文件上传
    uploadedFilePath = '';
    currentDownloadFile = '';
    elements.fileInput.value = '';
    
    // 清空表单
    elements.marketAuthor.value = '';
    elements.marketName.value = '';
    elements.marketVersion.value = '';
    elements.githubRepo.value = '';
    elements.githubRelease.value = '';
    elements.githubAsset.value = '';
    
    // 清除验证状态
    document.querySelectorAll('.is-invalid, .is-valid').forEach(el => {
        el.classList.remove('is-invalid', 'is-valid');
    });
    document.querySelectorAll('.invalid-feedback').forEach(el => el.remove());
    
    // 启用按钮
    elements.repackageBtn.disabled = false;
}

// 工具函数
function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

// 错误处理
window.addEventListener('error', function(e) {
    console.error('JavaScript错误:', e.error);
    addLog('发生错误: ' + e.error.message);
});

// 加载系统能力
function loadSystemCapabilities() {
    showLoadingOverlay('检测系统环境...');
    
    fetch('/api/capabilities')
        .then(response => response.json())
        .then(data => {
            systemCapabilities = data;
            updateUIBasedOnCapabilities();
            hideLoadingOverlay();
            // 选择默认模式
            selectDefaultMode();
        })
        .catch(error => {
            console.error('系统能力检测失败:', error);
            hideLoadingOverlay();
            showSystemError('系统环境检测失败，部分功能可能不可用');
            // 使用默认配置
            switchMode('local');
        });
}

// 根据系统能力更新UI
function updateUIBasedOnCapabilities() {
    if (!systemCapabilities) return;
    
    // 更新模式按钮状态
    const modeButtons = document.querySelectorAll('input[name="mode"]');
    modeButtons.forEach(radio => {
        const mode = radio.value;
        const label = radio.nextElementSibling;
        
        if (systemCapabilities.disabledModes.includes(mode)) {
            // 禁用模式
            radio.disabled = true;
            label.classList.add('disabled');
            label.style.opacity = '0.5';
            label.style.cursor = 'not-allowed';
            
            // 添加禁用原因提示
            const reasonDiv = document.createElement('div');
            reasonDiv.className = 'small text-danger mt-1';
            reasonDiv.innerHTML = '<i class="bi bi-exclamation-circle"></i> 环境不支持';
            label.appendChild(reasonDiv);
        } else if (systemCapabilities.recommendedModes.includes(mode)) {
            // 推荐模式
            const recommendDiv = document.createElement('div');
            recommendDiv.className = 'small text-success mt-1';
            recommendDiv.innerHTML = '<i class="bi bi-check-circle"></i> 推荐';
            label.appendChild(recommendDiv);
        }
    });
    
    // 显示系统状态信息
    showSystemStatus();
}

// 显示系统状态
function showSystemStatus() {
    if (!systemCapabilities) return;
    
    // 在页面顶部显示系统状态
    const statusContainer = document.createElement('div');
    statusContainer.className = 'alert alert-info mb-3';
    statusContainer.innerHTML = `
        <h6 class="alert-heading">
            <i class="bi bi-info-circle"></i>
            系统环境检测结果
        </h6>
        <div class="row small">
            <div class="col-md-6">
                <div class="mb-1">
                    <i class="bi bi-${systemCapabilities.dockerAvailable ? (systemCapabilities.dockerRunning ? 'check-circle text-success' : 'exclamation-triangle text-warning') : 'x-circle text-danger'}"></i>
                    Docker: ${systemCapabilities.dockerAvailable ? (systemCapabilities.dockerRunning ? '可用' : '已安装但未运行') : '未安装'}
                </div>
                <div class="mb-1">
                    <i class="bi bi-${systemCapabilities.pluginContainerRunning ? 'check-circle text-success' : 'x-circle text-danger'}"></i>
                    插件容器: ${systemCapabilities.pluginContainerRunning ? 
                        `运行中 (${systemCapabilities.pluginContainers.length}个)` : 
                        '未运行'}
                    ${systemCapabilities.pluginContainers && systemCapabilities.pluginContainers.length > 0 ? 
                        '<br><small class="text-muted ms-3">• ' + systemCapabilities.pluginContainers.join('<br><small class="text-muted ms-3">• ') + '</small>' : 
                        ''}
                </div>
                <div class="mb-1">
                    <i class="bi bi-${systemCapabilities.pythonAvailable ? 'check-circle text-success' : 'x-circle text-danger'}"></i>
                    Python: ${systemCapabilities.pythonAvailable ? systemCapabilities.pythonVersion : '未检测到'}
                </div>
                <div class="mb-1">
                    <i class="bi bi-${systemCapabilities.pipAvailable ? 'check-circle text-success' : 'x-circle text-danger'}"></i>
                    pip: ${systemCapabilities.pipAvailable ? '可用' : '不可用'}
                </div>
            </div>
            <div class="col-md-6">
                <div class="mb-1">
                    <i class="bi bi-${systemCapabilities.unzipAvailable ? 'check-circle text-success' : 'x-circle text-danger'}"></i>
                    unzip: ${systemCapabilities.unzipAvailable ? '可用' : '不可用'}
                </div>
                <div class="mb-1">
                    <i class="bi bi-${systemCapabilities.networkAvailable ? 'check-circle text-success' : 'x-circle text-danger'}"></i>
                    网络连接: ${systemCapabilities.networkAvailable ? '正常' : '不可用'}
                </div>
            </div>
        </div>
        ${systemCapabilities.warningMessages.length > 0 ? 
            '<hr><div class="warning-messages">' + 
            systemCapabilities.warningMessages.map(msg => `<div class="small">${msg}</div>`).join('') + 
            '</div>' : ''}
    `;
    
    // 插入到主卡片前面
    const mainCard = document.querySelector('.card');
    mainCard.parentNode.insertBefore(statusContainer, mainCard);
}

// 选择默认模式
function selectDefaultMode() {
    let defaultMode = 'local'; // 默认本地模式
    
    if (systemCapabilities && systemCapabilities.recommendedModes.length > 0) {
        defaultMode = systemCapabilities.recommendedModes[0];
    }
    
    // 选中默认模式
    const defaultRadio = document.getElementById('mode-' + defaultMode);
    if (defaultRadio && !defaultRadio.disabled) {
        defaultRadio.checked = true;
        switchMode(defaultMode);
    } else {
        // 如果默认模式不可用，选择第一个可用的模式
        const availableRadios = document.querySelectorAll('input[name="mode"]:not(:disabled)');
        if (availableRadios.length > 0) {
            availableRadios[0].checked = true;
            switchMode(availableRadios[0].value);
        }
    }
}

// 显示加载遮罩
function showLoadingOverlay(message) {
    const overlay = document.createElement('div');
    overlay.id = 'loading-overlay';
    overlay.className = 'loading-overlay';
    overlay.innerHTML = `
        <div class="loading-content">
            <div class="spinner-border text-primary mb-3" role="status"></div>
            <div class="loading-message">${message}</div>
        </div>
    `;
    
    // 添加样式
    const style = document.createElement('style');
    style.textContent = `
        .loading-overlay {
            position: fixed;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: rgba(255, 255, 255, 0.9);
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 9999;
        }
        .loading-content {
            text-align: center;
        }
        .loading-message {
            font-size: 1.1rem;
            color: #666;
        }
    `;
    document.head.appendChild(style);
    document.body.appendChild(overlay);
}

// 隐藏加载遮罩
function hideLoadingOverlay() {
    const overlay = document.getElementById('loading-overlay');
    if (overlay) {
        overlay.remove();
    }
}

// 显示系统错误
function showSystemError(message) {
    const errorDiv = document.createElement('div');
    errorDiv.className = 'alert alert-warning mb-3';
    errorDiv.innerHTML = `
        <h6 class="alert-heading">
            <i class="bi bi-exclamation-triangle"></i>
            系统提示
        </h6>
        <p class="mb-0">${message}</p>
    `;
    
    const mainCard = document.querySelector('.card');
    mainCard.parentNode.insertBefore(errorDiv, mainCard);
}

// 页面卸载前确认
window.addEventListener('beforeunload', function(e) {
    if (elements.progressSection.style.display !== 'none') {
        e.preventDefault();
        e.returnValue = '正在处理中，确定要离开吗？';
    }
}); 