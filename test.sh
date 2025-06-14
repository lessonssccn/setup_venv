#!/bin/bash

# Параметры
CONTAINER_NAME="test-container"
IMAGE="ubuntu:24.04"
GITHUB_SCRIPT_URL="https://raw.githubusercontent.com/lessonssccn/setup_venv/refs/heads/main/setup_venv.sh" 
SCRIPT_PATH="./setup_venv.sh"

# Флаги
INTERACTIVE_MODE=false
USE_EXISTING=false
REUSE_CONTAINER=false
FORCE_RESTART=false

# 1. Обработка аргументов командной строки
while getopts ":irn" opt; do
  case $opt in
    i)
      INTERACTIVE_MODE=true
      ;;
    r)
      REUSE_CONTAINER=true
      FORCE_RESTART=true
      ;;
    n)
      REUSE_CONTAINER=true
      USE_EXISTING=true
      ;;
    \?)
      echo "Использование: $0 [-i] [-r] [-n]"
      echo "  -i   : интерактивный режим (остаётесь в bash)"
      echo "  -r   : использовать существующий контейнер, перезапустив его"
      echo "  -n   : не удалять и не создавать новый контейнер"
      exit 1
      ;;
  esac
done

# 2. Проверяем, существует ли контейнер
CONTAINER_EXISTS=false
if lxc info $CONTAINER_NAME &> /dev/null; then
    CONTAINER_EXISTS=true
fi

# 3. Если не указан -n, удаляем старый контейнер (если есть)
if [ "$USE_EXISTING" = false ]; then
    if [ "$CONTAINER_EXISTS" = true ]; then
        echo "Удаляю старый контейнер..."
        lxc delete --force $CONTAINER_NAME
        CONTAINER_EXISTS=false
    fi
fi

# 4. Создаём или используем существующий контейнер
if [ "$CONTAINER_EXISTS" = true ] && [ "$REUSE_CONTAINER" = true ]; then
    # Если указан -r, перезапускаем
    if [ "$FORCE_RESTART" = true ]; then
        echo "Перезапускаю существующий контейнер..."
        lxc restart $CONTAINER_NAME
    else
        echo "Использую существующий запущенный контейнер..."
    fi
else
    echo "Создаю новый контейнер $CONTAINER_NAME на основе $IMAGE..."
    lxc launch $IMAGE $CONTAINER_NAME
    sleep 5
fi

# 5. Скачиваем скрипт из GitHub
echo "Скачиваю скрипт из GitHub..."
lxc exec $CONTAINER_NAME -- sh -c "curl -o $SCRIPT_PATH $GITHUB_SCRIPT_URL && chmod +x $SCRIPT_PATH"

# 6. Выполняем скрипт внутри контейнера
echo "Выполняю скрипт внутри контейнера..."
lxc exec $CONTAINER_NAME -- sh -c "$SCRIPT_PATH -f"

# 7. Интерактивный режим или удаление
if [ "$INTERACTIVE_MODE" = true ]; then
    echo "Перехожу в интерактивный режим. Подключаюсь к bash в контейнере..."
    echo "Чтобы выйти, нажмите Ctrl+D или введите 'exit'"
    lxc exec $CONTAINER_NAME -- bash
    echo "Контейнер остался на хосте. Чтобы удалить вручную:"
    echo "  lxc stop $CONTAINER_NAME"
    echo "  lxc delete $CONTAINER_NAME"
else
    if [ "$USE_EXISTING" = false ] && [ "$REUSE_CONTAINER" = false ]; then
        echo "Останавливаю и удаляю временный контейнер..."
        lxc stop $CONTAINER_NAME
        lxc delete --force $CONTAINER_NAME
    else
        echo "Контейнер сохранён на хосте."
    fi
fi

echo "Готово!"