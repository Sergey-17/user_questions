@echo off
chcp 65001 >nul
REM Скрипт для деплоя проекта на DockerHub и локально (Windows Batch)
REM Автор: Sergey

setlocal enabledelayedexpansion

REM Параметры командной строки
set SKIP_BUILD=0
set SKIP_PUSH=0
set SKIP_LOCAL=0

REM Обработка параметров
:parse_args
if "%1"=="-SkipBuild" (
    set SKIP_BUILD=1
    shift
    goto parse_args
)
if "%1"=="-SkipPush" (
    set SKIP_PUSH=1
    shift
    goto parse_args
)
if "%1"=="-SkipLocal" (
    set SKIP_LOCAL=1
    shift
    goto parse_args
)
if "%1"=="" goto start_deploy
shift
goto parse_args

:start_deploy
echo.
echo [INFO] 🚀 Начинаем деплой проекта...
echo.

REM Проверяем наличие Docker
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Docker не установлен. Установите Docker и попробуйте снова.
    exit /b 1
)
echo [SUCCESS] Docker найден

REM Проверяем наличие docker-compose
docker-compose --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] docker-compose не установлен. Установите docker-compose и попробуйте снова.
    exit /b 1
)
echo [SUCCESS] docker-compose найден

REM Собираем образы
if %SKIP_BUILD%==0 (
    echo [INFO] Собираем Docker образы...
    
    echo [INFO] Собираем образ для backend...
    docker build -f Backend-Dockerfile -t sergey17/backend:latest .
    if %errorlevel% neq 0 (
        echo [ERROR] Ошибка при сборке образа sergey17/backend:latest
        exit /b 1
    )
    echo [SUCCESS] Образ sergey17/backend:latest успешно собран
    
    echo [INFO] Собираем образ для frontend...
    docker build -f Frontend-Dockerfile -t sergey17/frontend:latest .
    if %errorlevel% neq 0 (
        echo [ERROR] Ошибка при сборке образа sergey17/frontend:latest
        exit /b 1
    )
    echo [SUCCESS] Образ sergey17/frontend:latest успешно собран
)

REM Пушим образы в Docker Hub
if %SKIP_PUSH%==0 (
    echo [INFO] Пушим образы в Docker Hub...
    
    echo [INFO] Пушим образ sergey17/backend:latest в Docker Hub...
    docker push sergey17/backend:latest
    if %errorlevel% neq 0 (
        echo [ERROR] Ошибка при пуше образа sergey17/backend:latest
        exit /b 1
    )
    echo [SUCCESS] Образ sergey17/backend:latest успешно запушен в Docker Hub
    
    echo [INFO] Пушим образ sergey17/frontend:latest в Docker Hub...
    docker push sergey17/frontend:latest
    if %errorlevel% neq 0 (
        echo [ERROR] Ошибка при пуше образа sergey17/frontend:latest
        exit /b 1
    )
    echo [SUCCESS] Образ sergey17/frontend:latest успешно запушен в Docker Hub
)


echo.
echo [SUCCESS] 🎉 Деплой завершен успешно!
echo [INFO] Образы доступны в Docker Hub:
echo [INFO]   - sergey17/backend:latest
echo [INFO]   - sergey17/frontend:latest
echo.
echo [INFO] Для деплоя на сервер используйте deploy-server.bat
echo.

endlocal