#!/bin/bash

set -euo pipefail  # Добавляем строгий режим выполнения

# Константы
readonly STATE_FILE="/var/tmp/xanmod_install_state"
readonly LOG_FILE="/var/log/xanmod_install.log"
readonly SYSCTL_CONFIG="/etc/sysctl.d/99-bbr.conf"

# Функция логирования
log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# Функция проверки зависимостей
check_dependencies() {
    local deps=(awk grep add-apt-repository apt)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log "Ошибка: Команда '$dep' не найдена"
            exit 1
        fi
    done
}

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log "Ошибка: Этот скрипт должен быть запущен с правами root."
        exit 1
    fi
}

# Проверка операционной системы
check_os() {
    if ! grep -E -q "Ubuntu|Debian" /etc/os-release; then
        log "Ошибка: Этот скрипт поддерживает только Ubuntu и Debian."
        exit 1
    fi
}

# Функция для проверки PSABI версии
get_psabi_version() {
    awk '
    BEGIN { level = 0 }
    /flags/ {
        if ($0 ~ /lm/ && $0 ~ /cmov/ && $0 ~ /cx8/ && $0 ~ /fpu/ && $0 ~ /fxsr/ && $0 ~ /mmx/ && $0 ~ /syscall/ && $0 ~ /sse2/) level = 1
        if (level == 1 && $0 ~ /cx16/ && $0 ~ /lahf/ && $0 ~ /popcnt/ && $0 ~ /sse4_1/ && $0 ~ /sse4_2/ && $0 ~ /ssse3/) level = 2
        if (level == 2 && $0 ~ /avx/ && $0 ~ /avx2/ && $0 ~ /bmi1/ && $0 ~ /bmi2/ && $0 ~ /f16c/ && $0 ~ /fma/ && $0 ~ /abm/ && $0 ~ /movbe/ && $0 ~ /xsave/) level = 3
        if (level == 3 && $0 ~ /avx512f/ && $0 ~ /avx512bw/ && $0 ~ /avx512cd/ && $0 ~ /avx512dq/ && $0 ~ /avx512vl/) level = 4
        if (level > 0) { print "x64v" level; exit (level + 1) }
    }
    END {
        if (level == 0) {
            print "x64v1"
            exit 2
        }
    }' /proc/cpuinfo
}

# Функция для установки ядра
install_kernel() {
    log "Начало установки ядра..."

    # Установка software-properties-common, если отсутствует
    if ! command -v add-apt-repository &> /dev/null; then
        apt-get update || { log "Ошибка при обновлении списка пакетов."; exit 1; }
        apt-get install -y software-properties-common || { log "Ошибка при установке software-properties-common."; exit 1; }
    fi

    # Определение PSABI версии
    local PSABI_VERSION
    PSABI_VERSION=$(get_psabi_version)
    if [[ -z "$PSABI_VERSION" || ! "$PSABI_VERSION" =~ ^x64v[1-4]$ ]]; then
        log "Ошибка: Некорректная версия PSABI: $PSABI_VERSION"
        exit 1
    fi

    log "Определена PSABI версия: $PSABI_VERSION"

    # Выбор ветки обновлений с таймаутом
    local BRANCH
    local TIMEOUT=60
    echo "У вас есть $TIMEOUT секунд для выбора ветки обновлений"
    while true; do
        read -t $TIMEOUT -p "Выберите ветку обновлений (1 - Main, 2 - Edge, 3 - LTS, 4 - RT): " branch_choice || { log "Превышено время ожидания. Выбрана ветка Main."; branch_choice=1; }
        case $branch_choice in
            1) BRANCH="main"; break ;;
            2) BRANCH="edge"; break ;;
            3) BRANCH="lts"; break ;;
            4) BRANCH="rt"; break ;;
            *) log "Пожалуйста, выберите 1, 2, 3 или 4." ;;
        esac
    done

    # Формирование имени пакета
    local KERNEL_PACKAGE
    if [[ $BRANCH == "main" ]]; then
        KERNEL_PACKAGE="linux-xanmod-$PSABI_VERSION"
    else
        KERNEL_PACKAGE="linux-xanmod-$BRANCH-$PSABI_VERSION"
    fi

    log "Будет установлено ядро: $KERNEL_PACKAGE"

    # Создание резервной копии текущего ядра
    local BACKUP_DIR="/var/backups/kernel_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    cp -r /boot/* "$BACKUP_DIR/" || log "Предупреждение: Не удалось создать резервную копию ядра"

    # Обновление и установка
    apt-get update || { log "Ошибка при обновлении списка пакетов."; exit 1; }

    # Проверка наличия репозитория Xanmod
    if ! grep -q "^deb .*/xanmod/kernel" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null; then
        log "Добавление PPA репозитория Xanmod..."
        add-apt-repository -y ppa:xanmod/kernel || { log "Ошибка при добавлении репозитория."; exit 1; }
        apt-get update || { log "Ошибка при обновлении списка пакетов после добавления репозитория."; exit 1; }
    fi

    # Установка выбранного ядра
    apt-get install -y "$KERNEL_PACKAGE" || { log "Ошибка при установке ядра."; exit 1; }

    # Обновление GRUB
    update-grub || { log "Ошибка при обновлении GRUB."; exit 1; }

    # Сохранение состояния перед перезагрузкой
    echo "kernel_installed" > "$STATE_FILE"
}

# Функция для настройки TCP BBR
configure_bbr() {
    log "Начало настройки TCP BBR..."

    # Проверка наличия флага состояния
    if [[ ! -f "$STATE_FILE" || $(cat "$STATE_FILE") != "kernel_installed" ]]; then
        log "Ядро еще не установлено. Завершение работы."
        exit 1
    fi

    # Включение TCP BBR
    log "Включение TCP BBR..."
    cat <<EOF > "$SYSCTL_CONFIG"
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

    sysctl --system || { log "Ошибка при применении настроек sysctl."; exit 1; }

    # Проверка статуса BBR
    log "Проверка статуса TCP BBR..."
    if [[ $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}') == "bbr" ]]; then
        log "TCP BBR успешно включен."
    else
        log "Ошибка: TCP BBR не включен."
        exit 1
    fi

    # Проверка наличия BBR в очереди диска
    if [[ $(sysctl net.core.default_qdisc | awk '{print $3}') == "fq" ]]; then
        log "Очередь диска 'fq' успешно настроена."
    else
        log "Ошибка: Очередь диска 'fq' не настроена."
        exit 1
    fi

    # Удаление файла-флага
    rm -f "$STATE_FILE"
}

# Обработчик прерываний
cleanup() {
    log "Скрипт был прерван. Очистка..."
    rm -f "$STATE_FILE"
    exit 1
}

# Установка обработчиков сигналов
trap cleanup INT TERM QUIT

# Главная функция
main() {
    # Инициализация
    check_root
    check_os
    check_dependencies

    # Проверка наличия файла-флага
    if [[ -f "$STATE_FILE" && $(cat "$STATE_FILE") == "kernel_installed" ]]; then
        log "Обнаружен файл-флаг. Продолжение настройки TCP BBR..."
        configure_bbr
        exit 0
    fi

    # Установка ядра
    install_kernel

    # Перезагрузка системы
    read -t 60 -p "Установка завершена. Хотите перезагрузить систему сейчас? (y/n): " reboot_choice || { log "Превышено время ожидания. Система не будет перезагружена."; exit 0; }
    if [[ $reboot_choice == "y" || $reboot_choice == "Y" ]]; then
        log "Перезагрузка системы..."
        reboot
    else
        log "Не забудьте перезагрузить систему вручную для применения изменений."
    fi
}

# Запуск главной функции
main