#!/bin/bash

# Скрипт для деплоя проекта на удалённый сервер
# Сервер: 95.81.114.223
# Автор: Sergey

set -e  # Остановка при ошибке

echo "🚀 Начинаем деплой на удалённый сервер..."

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Конфигурация сервера
SERVER_IP="95.81.114.223"
SERVER_USER="root"  # Измените на нужного пользователя
PROJECT_DIR="/opt/user_questions"
DOCKER_COMPOSE_FILE="docker-compose.prod.yml"

# Функции для вывода сообщений
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Проверяем наличие SSH ключа
check_ssh_connection() {
    log "Проверяем SSH соединение с сервером ${SERVER_IP}..."
    
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes ${SERVER_USER}@${SERVER_IP} "echo 'SSH connection successful'" &> /dev/null; then
        error "Не удается подключиться к серверу ${SERVER_IP}"
        error "Убедитесь что:"
        error "1. SSH ключ настроен правильно"
        error "2. Сервер доступен"
        error "3. Пользователь ${SERVER_USER} существует"
        exit 1
    fi
    
    success "SSH соединение установлено"
}

# Проверяем наличие Docker на сервере
check_docker_on_server() {
    log "Проверяем наличие Docker на сервере..."
    
    if ! ssh ${SERVER_USER}@${SERVER_IP} "command -v docker" &> /dev/null; then
        error "Docker не установлен на сервере"
        log "Установите Docker на сервере и попробуйте снова"
        exit 1
    fi
    
    if ! ssh ${SERVER_USER}@${SERVER_IP} "command -v docker-compose" &> /dev/null; then
        error "docker-compose не установлен на сервере"
        log "Установите docker-compose на сервере и попробуйте снова"
        exit 1
    fi
    
    success "Docker и docker-compose установлены на сервере"
}

# Создаем директорию проекта на сервере
setup_project_directory() {
    log "Создаем директорию проекта на сервере..."
    
    ssh ${SERVER_USER}@${SERVER_IP} "mkdir -p ${PROJECT_DIR}"
    success "Директория ${PROJECT_DIR} создана"
}

# Копируем файлы на сервер
copy_files_to_server() {
    log "Копируем файлы на сервер..."
    
    # Копируем docker-compose.prod.yml
    if [ -f "docker-compose.prod.yml" ]; then
        scp docker-compose.prod.yml ${SERVER_USER}@${SERVER_IP}:${PROJECT_DIR}/
        success "docker-compose.prod.yml скопирован"
    else
        error "Файл docker-compose.prod.yml не найден"
        error "Сначала запустите deploy.sh для создания продакшен файлов"
        exit 1
    fi
    
    # Копируем .env файл (если существует)
    if [ -f ".env" ]; then
        scp .env ${SERVER_USER}@${SERVER_IP}:${PROJECT_DIR}/
        success ".env файл скопирован"
    else
        warning ".env файл не найден. Создайте его на сервере вручную"
    fi
}

# Останавливаем старые контейнеры
stop_old_containers() {
    log "Останавливаем старые контейнеры..."
    
    ssh ${SERVER_USER}@${SERVER_IP} "cd ${PROJECT_DIR} && docker-compose -f ${DOCKER_COMPOSE_FILE} down" || true
    success "Старые контейнеры остановлены"
}

# Обновляем образы на сервере
update_images_on_server() {
    log "Обновляем образы на сервере..."
    
    ssh ${SERVER_USER}@${SERVER_IP} "docker pull sergey17/backend:latest"
    ssh ${SERVER_USER}@${SERVER_IP} "docker pull sergey17/frontend:latest"
    
    success "Образы обновлены на сервере"
}

# Запускаем приложение на сервере
start_application() {
    log "Запускаем приложение на сервере..."
    
    ssh ${SERVER_USER}@${SERVER_IP} "cd ${PROJECT_DIR} && docker-compose -f ${DOCKER_COMPOSE_FILE} up -d"
    
    if [ $? -eq 0 ]; then
        success "Приложение успешно запущено на сервере"
    else
        error "Ошибка при запуске приложения"
        exit 1
    fi
}

# Проверяем статус приложения
check_application_status() {
    log "Проверяем статус приложения..."
    
    sleep 10  # Даем время на запуск
    
    # Проверяем статус контейнеров
    ssh ${SERVER_USER}@${SERVER_IP} "cd ${PROJECT_DIR} && docker-compose -f ${DOCKER_COMPOSE_FILE} ps"
    
    # Проверяем доступность сервисов
    log "Проверяем доступность сервисов..."
    
    if curl -s -f http://${SERVER_IP}:8000/health &> /dev/null; then
        success "Backend доступен на http://${SERVER_IP}:8000"
    else
        warning "Backend может быть недоступен на http://${SERVER_IP}:8000"
    fi
    
    if curl -s -f http://${SERVER_IP}:5173 &> /dev/null; then
        success "Frontend доступен на http://${SERVER_IP}:5173"
    else
        warning "Frontend может быть недоступен на http://${SERVER_IP}:5173"
    fi
}

# Показываем логи
show_logs() {
    log "Показываем логи приложения (последние 20 строк)..."
    ssh ${SERVER_USER}@${SERVER_IP} "cd ${PROJECT_DIR} && docker-compose -f ${DOCKER_COMPOSE_FILE} logs --tail=20"
}

# Основная функция деплоя
main() {
    log "Начинаем деплой на сервер ${SERVER_IP}"
    
    # Проверяем соединение
    check_ssh_connection
    check_docker_on_server
    
    # Настраиваем проект
    setup_project_directory
    copy_files_to_server
    
    # Деплоим приложение
    stop_old_containers
    update_images_on_server
    start_application
    
    # Проверяем результат
    check_application_status
    show_logs
    
    success "🎉 Деплой на сервер завершен успешно!"
    log ""
    log "Приложение доступно по адресам:"
    log "  - Backend: http://${SERVER_IP}:8000"
    log "  - Frontend: http://${SERVER_IP}:5173"
    log ""
    log "Для просмотра логов выполните:"
    log "  ssh ${SERVER_USER}@${SERVER_IP} 'cd ${PROJECT_DIR} && docker-compose -f ${DOCKER_COMPOSE_FILE} logs -f'"
    log ""
    log "Для остановки приложения выполните:"
    log "  ssh ${SERVER_USER}@${SERVER_IP} 'cd ${PROJECT_DIR} && docker-compose -f ${DOCKER_COMPOSE_FILE} down'"
}

# Запускаем деплой
main "$@"
