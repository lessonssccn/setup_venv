# Основные аргументы сборки
ARG PYTHON_VERSION=3.12
ARG INSTALL_LOCALE=false
ARG LOCALE=ru_RU
ARG CHARSET=UTF-8

FROM ubuntu:24.04 AS base
WORKDIR /test

# Установка локали (если INSTALL_LOCALE=true)
RUN if [ "$INSTALL_LOCALE" = "true" ]; then \
        apt-get update && \
        apt-get install -y --no-install-recommends locales && \
        localedef -i ${LOCALE} -c -f ${CHARSET} -A /usr/share/locale/locale.alias ${LOCALE}.${CHARSET} && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/*; \
    fi

# Минимальная стадия — ничего не устанавливаем
FROM base AS minimal

# Установка Python
FROM base AS with-python
ARG PYTHON_VERSION
RUN apt-get update && \
    apt-get install -y --no-install-recommends python${PYTHON_VERSION} && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Образ с venv
FROM with-python AS with-python-venv
ARG PYTHON_VERSION
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-venv && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Образ с pip
FROM with-python AS with-python-pip
ARG PYTHON_VERSION
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Полный образ с venv и pip
FROM with-python AS with-python-full
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3-venv \
        python3-pip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*