#!/bin/bash

# Скрипт для деплоя проекта на DockerHub и локально
# Автор: Sergey
# Дата: $(date)

set -e  # Остановка при ошибке

echo "🚀 Начинаем деплой проекта..."

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
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

# Проверяем наличие Docker
if ! command -v docker &> /dev/null; then
    error "Docker не установлен. Установите Docker и попробуйте снова."
    exit 1
fi

# Проверяем наличие docker-compose
if ! command -v docker-compose &> /dev/null; then
    error "docker-compose не установлен. Установите docker-compose и попробуйте снова."
    exit 1
fi

# Проверяем авторизацию в Docker Hub
log "Проверяем авторизацию в Docker Hub..."
if ! docker info | grep -q "Username: sergey17"; then
    warning "Не авторизованы в Docker Hub как sergey17"
    log "Выполните: docker login"
    read -p "Продолжить без авторизации? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Функция для сборки и тегирования образа
build_and_tag() {
    local service=$1
    local dockerfile=$2
    local tag="sergey17/${service}:latest"
    
    log "Собираем образ для ${service}..."
    docker build -f ${dockerfile} -t ${tag} .
    
    if [ $? -eq 0 ]; then
        success "Образ ${tag} успешно собран"
    else
        error "Ошибка при сборке образа ${tag}"
        exit 1
    fi
}

# Функция для пуша образа в Docker Hub
push_image() {
    local service=$1
    local tag="sergey17/${service}:latest"
    
    log "Пушим образ ${tag} в Docker Hub..."
    docker push ${tag}
    
    if [ $? -eq 0 ]; then
        success "Образ ${tag} успешно запушен в Docker Hub"
    else
        error "Ошибка при пуше образа ${tag}"
        exit 1
    fi
}

# Собираем образы
log "Собираем Docker образы..."
build_and_tag "backend" "Backend-Dockerfile"
build_and_tag "frontend" "Frontend-Dockerfile"

# Пушим образы в Docker Hub
log "Пушим образы в Docker Hub..."
push_image "backend"
push_image "frontend"

# Создаем docker-compose для продакшена
log "Создаем docker-compose.prod.yml для продакшена..."
cat > docker-compose.prod.yml << EOF
version: '3.8'
services:
  backend:
    image: sergey17/backend:latest
    ports:
      - "8000:8000"
    environment:
      - OPENAI_API_KEY=\${OPENAI_API_KEY}
      - OPENAI_BASE_URL=\${OPENAI_BASE_URL}
      - OPENAI_MODEL=\${OPENAI_MODEL}
      - OPENAI_SYSTEM_PROMPT=\${OPENAI_SYSTEM_PROMPT}
      - OPENAI_MAX_TOKENS=\${OPENAI_MAX_TOKENS}
    restart: unless-stopped
  frontend:
    image: sergey17/frontend:latest
    ports:
      - "5173:5173"
    restart: unless-stopped
EOF

success "docker-compose.prod.yml создан"

# Запускаем локально для тестирования
log "Запускаем проект локально для тестирования..."
docker-compose -f docker-compose.prod.yml up -d

if [ $? -eq 0 ]; then
    success "Проект успешно запущен локально"
    log "Backend доступен на: http://localhost:8000"
    log "Frontend доступен на: http://localhost:5173"
    log "Для остановки выполните: docker-compose -f docker-compose.prod.yml down"
else
    error "Ошибка при запуске проекта локально"
    exit 1
fi

success "🎉 Деплой завершен успешно!"
log "Образы доступны в Docker Hub:"
log "  - sergey17/backend:latest"
log "  - sergey17/frontend:latest"
log ""
log "Для деплоя на сервер используйте deploy-server.sh"
