# Скрипт для деплоя проекта на удалённый сервер (PowerShell)
# Сервер: 95.81.114.223
# Автор: Sergey

param(
    [string]$ServerUser = "root",
    [switch]$SkipCopy,
    [switch]$SkipStop
)

# Конфигурация сервера
$SERVER_IP = "95.81.114.223"
$PROJECT_DIR = "/opt/user_questions"
$DOCKER_COMPOSE_FILE = "docker-compose.prod.yml"

# Функции для вывода сообщений
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

Write-Info "🚀 Начинаем деплой на удалённый сервер..."

# Проверяем наличие SSH
function Test-SSHConnection {
    Write-Info "Проверяем SSH соединение с сервером $SERVER_IP..."
    
    try {
        ssh -o ConnectTimeout=10 -o BatchMode=yes "${ServerUser}@${SERVER_IP}" "echo 'SSH connection successful'" 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "SSH соединение установлено"
        } else {
            throw "SSH connection failed"
        }
    } catch {
        Write-Error "Не удается подключиться к серверу $SERVER_IP"
        Write-Error "Убедитесь что:"
        Write-Error "1. SSH ключ настроен правильно"
        Write-Error "2. Сервер доступен"
        Write-Error "3. Пользователь $ServerUser существует"
        exit 1
    }
}

# Проверяем наличие Docker на сервере
function Test-DockerOnServer {
    Write-Info "Проверяем наличие Docker на сервере..."
    
    try {
        ssh "${ServerUser}@${SERVER_IP}" "command -v docker" 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker not found"
        }
        
        ssh "${ServerUser}@${SERVER_IP}" "command -v docker-compose" 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "docker-compose not found"
        }
        
        Write-Success "Docker и docker-compose установлены на сервере"
    } catch {
        Write-Error "Docker или docker-compose не установлены на сервере"
        Write-Info "Установите Docker и docker-compose на сервере и попробуйте снова"
        exit 1
    }
}

# Создаем директорию проекта на сервере
function New-ProjectDirectory {
    Write-Info "Создаем директорию проекта на сервере..."
    
    ssh "${ServerUser}@${SERVER_IP}" "mkdir -p $PROJECT_DIR"
    Write-Success "Директория $PROJECT_DIR создана"
}

# Копируем файлы на сервер
function Copy-FilesToServer {
    Write-Info "Копируем файлы на сервер..."
    
    # Копируем docker-compose.prod.yml
    if (Test-Path "docker-compose.prod.yml") {
        scp docker-compose.prod.yml "${ServerUser}@${SERVER_IP}:${PROJECT_DIR}/"
        Write-Success "docker-compose.prod.yml скопирован"
    } else {
        Write-Error "Файл docker-compose.prod.yml не найден"
        Write-Error "Сначала запустите deploy.ps1 для создания продакшен файлов"
        exit 1
    }
    
    # Копируем .env файл (если существует)
    if (Test-Path ".env") {
        scp .env "${ServerUser}@${SERVER_IP}:${PROJECT_DIR}/"
        Write-Success ".env файл скопирован"
    } else {
        Write-Warning ".env файл не найден. Создайте его на сервере вручную"
    }
}

# Останавливаем старые контейнеры
function Stop-OldContainers {
    Write-Info "Останавливаем старые контейнеры..."
    
    ssh "${ServerUser}@${SERVER_IP}" "cd $PROJECT_DIR && docker-compose -f $DOCKER_COMPOSE_FILE down" 2>$null
    Write-Success "Старые контейнеры остановлены"
}

# Обновляем образы на сервере
function Update-ImagesOnServer {
    Write-Info "Обновляем образы на сервере..."
    
    ssh "${ServerUser}@${SERVER_IP}" "docker pull sergey17/backend:latest"
    ssh "${ServerUser}@${SERVER_IP}" "docker pull sergey17/frontend:latest"
    
    Write-Success "Образы обновлены на сервере"
}

# Запускаем приложение на сервере
function Start-Application {
    Write-Info "Запускаем приложение на сервере..."
    
    ssh "${ServerUser}@${SERVER_IP}" "cd $PROJECT_DIR && docker-compose -f $DOCKER_COMPOSE_FILE up -d"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Приложение успешно запущено на сервере"
    } else {
        Write-Error "Ошибка при запуске приложения"
        exit 1
    }
}

# Проверяем статус приложения
function Test-ApplicationStatus {
    Write-Info "Проверяем статус приложения..."
    
    Start-Sleep -Seconds 10  # Даем время на запуск
    
    # Проверяем статус контейнеров
    ssh "${ServerUser}@${SERVER_IP}" "cd $PROJECT_DIR && docker-compose -f $DOCKER_COMPOSE_FILE ps"
    
    # Проверяем доступность сервисов
    Write-Info "Проверяем доступность сервисов..."
    
    try {
        Invoke-WebRequest -Uri "http://${SERVER_IP}:8000/health" -TimeoutSec 10 -ErrorAction Stop | Out-Null
        Write-Success "Backend доступен на http://${SERVER_IP}:8000"
    } catch {
        Write-Warning "Backend может быть недоступен на http://${SERVER_IP}:8000"
    }
    
    try {
        Invoke-WebRequest -Uri "http://${SERVER_IP}:5173" -TimeoutSec 10 -ErrorAction Stop | Out-Null
        Write-Success "Frontend доступен на http://${SERVER_IP}:5173"
    } catch {
        Write-Warning "Frontend может быть недоступен на http://${SERVER_IP}:5173"
    }
}

# Показываем логи
function Show-Logs {
    Write-Info "Показываем логи приложения (последние 20 строк)..."
    ssh "${ServerUser}@${SERVER_IP}" "cd $PROJECT_DIR && docker-compose -f $DOCKER_COMPOSE_FILE logs --tail=20"
}

# Основная функция деплоя
function Start-Deploy {
    Write-Info "Начинаем деплой на сервер $SERVER_IP"
    
    # Проверяем соединение
    Test-SSHConnection
    Test-DockerOnServer
    
    # Настраиваем проект
    New-ProjectDirectory
    
    if (-not $SkipCopy) {
        Copy-FilesToServer
    }
    
    # Деплоим приложение
    if (-not $SkipStop) {
        Stop-OldContainers
    }
    Update-ImagesOnServer
    Start-Application
    
    # Проверяем результат
    Test-ApplicationStatus
    Show-Logs
    
    Write-Success "🎉 Деплой на сервер завершен успешно!"
    Write-Info ""
    Write-Info "Приложение доступно по адресам:"
    Write-Info "  - Backend: http://${SERVER_IP}:8000"
    Write-Info "  - Frontend: http://${SERVER_IP}:5173"
    Write-Info ""
    Write-Info "Для просмотра логов выполните:"
    Write-Info "  ssh ${ServerUser}@${SERVER_IP} 'cd $PROJECT_DIR && docker-compose -f $DOCKER_COMPOSE_FILE logs -f'"
    Write-Info ""
    Write-Info "Для остановки приложения выполните:"
    Write-Info "  ssh ${ServerUser}@${SERVER_IP} 'cd $PROJECT_DIR && docker-compose -f $DOCKER_COMPOSE_FILE down'"
}

# Запускаем деплой
Start-Deploy
