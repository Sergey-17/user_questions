# Инструкции по деплою проекта

Этот документ содержит инструкции по деплою проекта на DockerHub и удалённый сервер.

## Предварительные требования

### Локальная машина
- Docker и Docker Compose установлены
- SSH ключ настроен для доступа к серверу
- Авторизация в Docker Hub (ник: sergey17)

### Удалённый сервер (95.81.114.223)
- Docker и Docker Compose установлены
- SSH доступ настроен
- Пользователь с правами на запуск Docker

## Скрипты деплоя

### 1. deploy.sh / deploy.bat
Скрипт для деплоя на DockerHub и локального тестирования.

**Для Linux/macOS:**
```bash
chmod +x deploy.sh
./deploy.sh
```

**Для Windows:**
```cmd
deploy.bat
```

**Что делает скрипт:**
- Собирает Docker образы для backend и frontend
- Тегирует их для Docker Hub: `sergey17/backend:latest`, `sergey17/frontend:latest`
- Пушит образы в Docker Hub
- Создаёт `docker-compose.prod.yml` для продакшена
- Запускает проект локально для тестирования

**Параметры для Windows (deploy.bat):**
- `-SkipBuild` - пропустить сборку образов
- `-SkipPush` - пропустить пуш в Docker Hub
- `-SkipLocal` - пропустить локальный запуск

### 2. deploy-server.sh / deploy-server.bat
Скрипт для деплоя на удалённый сервер.

**Для Linux/macOS:**
```bash
chmod +x deploy-server.sh
./deploy-server.sh
```

**Для Windows:**
```cmd
deploy-server.bat
```

**Что делает скрипт:**
- Проверяет SSH соединение с сервером
- Проверяет наличие Docker на сервере
- Создаёт директорию проекта на сервере
- Копирует необходимые файлы
- Останавливает старые контейнеры
- Обновляет образы с Docker Hub
- Запускает приложение
- Проверяет статус и показывает логи

**Параметры для Windows (deploy-server.bat):**
- `-SkipCopy` - пропустить копирование файлов на сервер
- `-SkipStop` - пропустить остановку старых контейнеров

## Настройка окружения

### 1. Создание .env файла
Скопируйте `EnvExample.txt` в `.env` и заполните реальными значениями:

```bash
cp EnvExample.txt .env
```

### 2. Настройка SSH ключа
Убедитесь, что SSH ключ настроен для доступа к серверу:

```bash
ssh-copy-id root@95.81.114.223
```

### 3. Авторизация в Docker Hub
```bash
docker login
# Введите логин: sergey17
# Введите пароль: [ваш пароль]
```

## Пошаговый процесс деплоя

### Шаг 1: Подготовка
1. Убедитесь, что все файлы проекта готовы
2. Создайте `.env` файл с необходимыми переменными
3. Проверьте SSH соединение с сервером

### Шаг 2: Деплой на DockerHub
```bash
# Linux/macOS
./deploy.sh

# Windows
deploy.bat
```

### Шаг 3: Деплой на сервер
```bash
# Linux/macOS
./deploy-server.sh

# Windows
deploy-server.bat
```

## Проверка деплоя

После успешного деплоя приложение будет доступно по адресам:
- **Backend**: http://95.81.114.223:8000
- **Frontend**: http://95.81.114.223:5173

### Проверка статуса
```bash
ssh root@95.81.114.223 'cd /opt/user_questions && docker-compose -f docker-compose.prod.yml ps'
```

### Просмотр логов
```bash
ssh root@95.81.114.223 'cd /opt/user_questions && docker-compose -f docker-compose.prod.yml logs -f'
```

### Остановка приложения
```bash
ssh root@95.81.114.223 'cd /opt/user_questions && docker-compose -f docker-compose.prod.yml down'
```

## Устранение неполадок

### Проблема: SSH соединение не работает
**Решение:**
1. Проверьте, что сервер доступен: `ping 95.81.114.223`
2. Проверьте SSH ключ: `ssh -v root@95.81.114.223`
3. Убедитесь, что пользователь существует на сервере

### Проблема: Docker не установлен на сервере
**Решение:**
Установите Docker на сервере:
```bash
ssh root@95.81.114.223 'curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh'
ssh root@95.81.114.223 'curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose'
ssh root@95.81.114.223 'chmod +x /usr/local/bin/docker-compose'
```

### Проблема: Образы не пушатся в Docker Hub
**Решение:**
1. Проверьте авторизацию: `docker login`
2. Убедитесь, что у вас есть права на репозиторий `sergey17/backend` и `sergey17/frontend`

### Проблема: Приложение не запускается
**Решение:**
1. Проверьте логи: `ssh root@95.81.114.223 'cd /opt/user_questions && docker-compose -f docker-compose.prod.yml logs'`
2. Убедитесь, что `.env` файл создан на сервере
3. Проверьте, что все переменные окружения заполнены

## Дополнительные команды

### Обновление приложения
Для обновления приложения на сервере:
```bash
# Linux/macOS
./deploy-server.sh

# Windows
deploy-server.bat
```

### Примеры использования bat файлов

**Только сборка образов (без пуша и запуска):**
```cmd
deploy.bat -SkipPush -SkipLocal
```

**Только пуш в Docker Hub (без сборки и запуска):**
```cmd
deploy.bat -SkipBuild -SkipLocal
```

**Только локальный запуск (без сборки и пуша):**
```cmd
deploy.bat -SkipBuild -SkipPush
```

**Деплой на сервер без копирования файлов:**
```cmd
deploy-server.bat -SkipCopy
```

### Откат к предыдущей версии
```bash
ssh root@95.81.114.223 'cd /opt/user_questions && docker-compose -f docker-compose.prod.yml down'
ssh root@95.81.114.223 'docker pull sergey17/backend:previous-tag'
ssh root@95.81.114.223 'docker pull sergey17/frontend:previous-tag'
ssh root@95.81.114.223 'cd /opt/user_questions && docker-compose -f docker-compose.prod.yml up -d'
```

### Очистка неиспользуемых образов
```bash
ssh root@95.81.114.223 'docker system prune -f'
```

## Безопасность

- Никогда не коммитьте `.env` файл в репозиторий
- Используйте сильные пароли для Docker Hub
- Регулярно обновляйте образы для получения последних исправлений безопасности
- Настройте файрвол на сервере для ограничения доступа к портам

## Мониторинг

Для мониторинга состояния приложения можно использовать:
- Docker stats: `ssh root@95.81.114.223 'docker stats'`
- Логи приложения: `ssh root@95.81.114.223 'cd /opt/user_questions && docker-compose -f docker-compose.prod.yml logs -f'`
- Статус контейнеров: `ssh root@95.81.114.223 'cd /opt/user_questions && docker-compose -f docker-compose.prod.yml ps'`
