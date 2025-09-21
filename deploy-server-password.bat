@echo off
chcp 65001 >nul
REM Скрипт для деплоя проекта на удалённый сервер с паролем (Windows Batch)
REM Сервер: 95.81.114.223
REM Автор: Sergey

setlocal enabledelayedexpansion

REM Конфигурация сервера
set SERVER_IP=95.81.114.223
set SERVER_USER=root
set PROJECT_DIR=/opt/user_questions
set DOCKER_COMPOSE_FILE=docker-compose.prod.yml

echo.
echo [INFO] 🚀 Начинаем деплой на удалённый сервер...
echo [INFO] Сервер: %SERVER_IP%
echo [INFO] Пользователь: %SERVER_USER%
echo.

REM Проверяем наличие необходимых файлов
if not exist "docker-compose.prod.yml" (
    echo [ERROR] Файл docker-compose.prod.yml не найден
    echo [INFO] Сначала запустите: deploy.bat -SkipBuild -SkipPush -SkipLocal
    exit /b 1
)

echo [INFO] Файлы готовы к деплою
echo.

REM Проверяем SSH соединение
echo [INFO] Проверяем SSH соединение с сервером %SERVER_IP%...
echo [INFO] Введите пароль для пользователя %SERVER_USER%:
ssh -o ConnectTimeout=10 %SERVER_USER%@%SERVER_IP% "echo 'SSH connection successful'"
if %errorlevel% neq 0 (
    echo [ERROR] Не удается подключиться к серверу %SERVER_IP%
    echo [ERROR] Проверьте пароль и доступность сервера
    exit /b 1
)
echo [SUCCESS] SSH соединение установлено

REM Проверяем наличие Docker на сервере
echo [INFO] Проверяем наличие Docker на сервере...
ssh %SERVER_USER%@%SERVER_IP% "command -v docker"
if %errorlevel% neq 0 (
    echo [ERROR] Docker не установлен на сервере
    echo [INFO] Установите Docker на сервере и попробуйте снова
    exit /b 1
)

ssh %SERVER_USER%@%SERVER_IP% "command -v docker-compose"
if %errorlevel% neq 0 (
    echo [ERROR] docker-compose не установлен на сервере
    echo [INFO] Установите docker-compose на сервере и попробуйте снова
    exit /b 1
)
echo [SUCCESS] Docker и docker-compose установлены на сервере

REM Создаем директорию проекта на сервере
echo [INFO] Создаем директорию проекта на сервере...
ssh %SERVER_USER%@%SERVER_IP% "mkdir -p %PROJECT_DIR%"
echo [SUCCESS] Директория %PROJECT_DIR% создана

REM Копируем файлы на сервер
echo [INFO] Копируем файлы на сервер...
scp docker-compose.prod.yml %SERVER_USER%@%SERVER_IP%:%PROJECT_DIR%/
echo [SUCCESS] docker-compose.prod.yml скопирован

if exist ".env" (
    scp .env %SERVER_USER%@%SERVER_IP%:%PROJECT_DIR%/
    echo [SUCCESS] .env файл скопирован
) else (
    echo [WARNING] .env файл не найден. Создайте его на сервере вручную
)

REM Останавливаем старые контейнеры
echo [INFO] Останавливаем старые контейнеры...
ssh %SERVER_USER%@%SERVER_IP% "cd %PROJECT_DIR% && docker-compose -f %DOCKER_COMPOSE_FILE% down"
echo [SUCCESS] Старые контейнеры остановлены

REM Обновляем образы на сервере
echo [INFO] Обновляем образы на сервере...
ssh %SERVER_USER%@%SERVER_IP% "docker pull sergey17/backend:latest"
ssh %SERVER_USER%@%SERVER_IP% "docker pull sergey17/frontend:latest"
echo [SUCCESS] Образы обновлены на сервере

REM Запускаем приложение на сервере
echo [INFO] Запускаем приложение на сервере...
ssh %SERVER_USER%@%SERVER_IP% "cd %PROJECT_DIR% && docker-compose -f %DOCKER_COMPOSE_FILE% up -d"
if %errorlevel% neq 0 (
    echo [ERROR] Ошибка при запуске приложения
    exit /b 1
)
echo [SUCCESS] Приложение успешно запущено на сервере

REM Проверяем статус приложения
echo [INFO] Проверяем статус приложения...
timeout /t 10 /nobreak >nul

REM Проверяем статус контейнеров
ssh %SERVER_USER%@%SERVER_IP% "cd %PROJECT_DIR% && docker-compose -f %DOCKER_COMPOSE_FILE% ps"

REM Проверяем доступность сервисов
echo [INFO] Проверяем доступность сервисов...

curl -s -f http://%SERVER_IP%:8000/health >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] Backend доступен на http://%SERVER_IP%:8000
) else (
    echo [WARNING] Backend может быть недоступен на http://%SERVER_IP%:8000
)

curl -s -f http://%SERVER_IP%:5173 >nul 2>&1
if %errorlevel% equ 0 (
    echo [SUCCESS] Frontend доступен на http://%SERVER_IP%:5173
) else (
    echo [WARNING] Frontend может быть недоступен на http://%SERVER_IP%:5173
)

REM Показываем логи
echo [INFO] Показываем логи приложения (последние 20 строк)...
ssh %SERVER_USER%@%SERVER_IP% "cd %PROJECT_DIR% && docker-compose -f %DOCKER_COMPOSE_FILE% logs --tail=20"

echo.
echo [SUCCESS] 🎉 Деплой на сервер завершен успешно!
echo.
echo [INFO] Приложение доступно по адресам:
echo [INFO]   - Backend: http://%SERVER_IP%:8000
echo [INFO]   - Frontend: http://%SERVER_IP%:5173
echo.
echo [INFO] Для просмотра логов выполните:
echo [INFO]   ssh %SERVER_USER%@%SERVER_IP% 'cd %PROJECT_DIR% && docker-compose -f %DOCKER_COMPOSE_FILE% logs -f'
echo.
echo [INFO] Для остановки приложения выполните:
echo [INFO]   ssh %SERVER_USER%@%SERVER_IP% 'cd %PROJECT_DIR% && docker-compose -f %DOCKER_COMPOSE_FILE% down'
echo.

endlocal
