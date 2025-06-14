#!/bin/bash
# === Настройки ===
VENV_DIR="env"
PYTHON_VERSION="python3.12"
LOCALE_TO_INSTALL="ru_RU.UTF-8"
LOG_OUTPUT="/dev/tty"


APT_UPDATED=false
INSTALL_UTILS=false
INSTALL_LOCALE_ONLY=false

# === Цвета для вывода ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

export DEBIAN_FRONTEND=noninteractive
export TZ=Europe/Moscow


trap 'echo -e "\n${RED}❌ Скрипт прерван пользователем.${NC}"; exit 1' INT

if command -v sudo &>/dev/null; then SUDO=sudo; else SUDO=; fi

if [ -n "${VIRTUAL_ENV:-}" ]; then
    echo -e "${YELLOW}⚠️ Внимание: вы уже находитесь в виртуальном окружении. Продолжить? (y/N)${NC}"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${RED}❌ Операция отменена пользователем.${NC}"
        exit 1
    fi
fi

show_help() {
    echo -e "${BLUE}Использование: $0 [флаг]${NC}"
    echo "  -i|--install        Установить системные утилиты"
    echo "  -l|--locale         Настроить локаль"
    echo "  -f|--full           Полная установка (--install + --locale)"
    echo "  -q|--quiet          Без вывода лога процесса установки только шаги"
    exit 0
}

# === Функция: apt update (один раз) ===
update_apt_if_needed() {
    if [ "$APT_UPDATED" = false ]; then
        echo -e "${BLUE}🔄 Обновляю список пакетов (один раз)...${NC}"
        $SUDO apt update > $LOG_OUTPUT 2>&1
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Не удалось выполнить apt update. Проверьте интернет или права root.${NC}"
            exit 1
        fi
        APT_UPDATED=true
    fi
}

# === Функция установки одного системного пакета ===
install_package() {
    local package_name="$1"

    update_apt_if_needed

    echo -e "${BLUE}🔍 Проверяю наличие пакета: $package_name...${NC}"

    if dpkg -s "$package_name" &> $LOG_OUTPUT; then
        echo -e "${BLUE}✅ Пакет '$package_name' уже установлен.${NC}"
        return 0
    fi

    echo -e "${BLUE}🛠️ Устанавливаю пакет: $package_name...${NC}"
    $SUDO apt install -y "$package_name" > $LOG_OUTPUT 2>&1

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Успешно установлен: $package_name${NC}"
    else
        echo -e "${RED}❌ Ошибка при установке: $package_name${NC}"
        exit 1
    fi
}

# === Функция: гарантируем установку python3.12 и получаем его полный путь ===
ensure_python() {
    echo -e "${BLUE}🔍 Проверяю установку $PYTHON_VERSION ...${NC}"
    if ! command -v $PYTHON_VERSION &>/dev/null; then
        echo -e "${RED}❌ $PYTHON_VERSION не найден. Используйте флаг --install для установки.${NC}"
        exit 1
    fi

    PYTHON_BIN=$(command -v $PYTHON_VERSION)
    export PYTHON_BIN
    echo -e "${GREEN}✅ Найден $PYTHON_VERSION по пути: $PYTHON_BIN${NC}"
}

# === Функция: очистка системы после установки пакетов ===
cleanup_apt() {
    if [ "$APT_UPDATED" = true ]; then
        echo -e "${BLUE}🧹 Выполняю очистку системы после установки...${NC}"
        $SUDO apt autoremove -y > $LOG_OUTPUT 2>&1
        $SUDO apt autoclean -y > $LOG_OUTPUT 2>&1
        $SUDO apt clean -y > $LOG_OUTPUT 2>&1

        echo -e "${GREEN}✅ Система очищена от временных файлов и ненужных пакетов.${NC}"
    else
        echo -e "${YELLOW}ℹ️ Очистка не требуется: apt update не выполнялся.${NC}"
    fi
}

# === Функция: настройка локали ===
setup_locale() {
    if [[ ! "$LOCALE_TO_INSTALL" =~ ^[a-z]{2}_[A-Z]{2}\.UTF-8$ ]]; then
        echo -e "${RED}❌ Неверный формат локали. Используйте формат: ll_CC.UTF-8 (например, ru_RU.UTF-8)${NC}"
        exit 1
    fi
    echo -e "${BLUE}🌍 Настройка локали $LOCALE_TO_INSTALL...${NC}"

    # Установка пакета locales
    install_package "locales"
    # Создание локали
    LOCALE_NAME=$(echo "$LOCALE_TO_INSTALL" | awk -F"." '{print $1}')
    CHARSET=$(echo "$LOCALE_TO_INSTALL" | awk -F"." '{print $2}')
    
    if ! $SUDO localedef -i "$LOCALE_NAME" -c -f "$CHARSET" -A /usr/share/locale/locale.alias "$LOCALE_TO_INSTALL"; then
        echo -e "${RED}❌ Ошибка: не удалось создать локаль $LOCALE_TO_INSTALL${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Локаль $LOCALE_TO_INSTALL успешно настроена.${NC}"
}

# === Парсинг аргументов командной строки ===
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) show_help ;;
        -i|--install) INSTALL_UTILS=true ;;
        -l|--locale) INSTALL_LOCALE_ONLY=true ;;
        -f|--full)
            INSTALL_UTILS=true
            INSTALL_LOCALE_ONLY=true
            ;;
        -q|--quiet) LOG_OUTPUT="/dev/null";;
        *) echo -e "${RED}❌ Неизвестный параметр: $1${NC}" && exit 1 ;;
    esac
    shift
done

# === Проверка прав root при использовании любого "установочного" флага ===
if { [ "$INSTALL_UTILS" = true ] || [ "$INSTALL_LOCALE_ONLY" = true ]; } && [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ Ошибка: Для установки требуются права root (запустите через sudo).${NC}"
    exit 1
fi

# === Установка утилит (Python, venv, pip) ===
if [ "$INSTALL_UTILS" = true ]; then
    echo -e "${BLUE}🔧 Запускаю установку утилит...${NC}"

    install_package "$PYTHON_VERSION"
    install_package "$PYTHON_VERSION-venv"
    install_package "python3-pip"
fi

ensure_python

# === Установка локали ===
if [ "$INSTALL_LOCALE_ONLY" = true ]; then
    setup_locale
fi

# === Очистка системы (если был выполнен apt update) ===
if [ "$APT_UPDATED" = true ]; then
    cleanup_apt
fi

# === Проверяем и создаём виртуальное окружение + активируем его с повторными попытками ===
MAX_RETRIES=5
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    RETRY_COUNT=$((RETRY_COUNT + 1))

    # Проверяем наличие окружения
    if [ ! -d "$VENV_DIR" ]; then
        echo -e "${BLUE}🔄 Создаю новое виртуальное окружение в папке '$VENV_DIR' (попытка $RETRY_COUNT)${NC}"
        "$PYTHON_BIN" -m venv "$VENV_DIR"
    else
        echo -e "${BLUE}🔄 Использую существующее виртуальное окружение (попытка $RETRY_COUNT)${NC}"
    fi

    # Пробуем активировать
    if . "$VENV_DIR/bin/activate"; then
        echo -e "${GREEN}✅ Виртуальное окружение успешно активировано.${NC}"
        break
    else
        echo -e "${YELLOW}⚠️ Не удалось активировать виртуальное окружение. Очищаю и пробую снова... (попытка $RETRY_COUNT из $MAX_RETRIES)${NC}"
        
        # Удаляем текущее окружение, чтобы создать новое
        rm -rf "$VENV_DIR"

        # Делаем паузу, чтобы избежать проблем (не обязательно)
        sleep 1
    fi

    # Если превышено количество попыток
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        echo -e "${RED}❌ Превышено количество попыток активации виртуального окружения.${NC}"
        exit 1
    fi
done

# === Обновляем pip ===
echo -e "${BLUE}🔧 Обновляю pip...${NC}"
python -m pip --no-cache-dir install --upgrade pip > $LOG_OUTPUT 2>&1

# === Устанавливаем зависимости из requirements.txt ===
if [ -s "requirements.txt" ]; then
    echo -e "${BLUE}📦 Устанавливаю зависимости из requirements.txt...${NC}"
    pip install --no-cache-dir -r requirements.txt > $LOG_OUTPUT 2>&1
elif [ -f "requirements.txt" ]; then
    echo -e "${YELLOW}ℹ️ Файл requirements.txt пуст. Зависимости не установлены.${NC}"
else
    echo -e "${YELLOW}ℹ️ Файл requirements.txt не найден. Зависимости не установлены.${NC}"
fi

# === Готово ===
echo -e "${GREEN}✅ Виртуальное окружение успешно создано!${NC}"