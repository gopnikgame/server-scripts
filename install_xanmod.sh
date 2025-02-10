#!/bin/bash

# Путь к файлу-флагу
STATE_FILE="/var/tmp/xanmod_install_state"

# Лог-файл для записи ошибок и процесса выполнения
LOG_FILE="/var/log/xanmod_install.log"

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: Этот скрипт должен быть запущен с правами root." | tee -a "$LOG_FILE"
    exit 1
fi

# Проверка операционной системы
if ! grep -E -q "Ubuntu|Debian" /etc/os-release; then
    echo "Ошибка: Этот скрипт поддерживает только Ubuntu и Debian." | tee -a "$LOG_FILE"
    exit 1
fi

# Функция для проверки PSABI версии
get_psabi_version() {
    local level=0
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
    echo "Начало установки ядра..." | tee -a "$LOG_FILE"

    # Установка software-properties-common, если отсутствует
    if ! command -v add-apt-repository &> /dev/null; then
        apt update || { echo "Ошибка при обновлении списка пакетов." | tee -a "$LOG_FILE"; exit 1; }
        apt install -y software-properties-common || { echo "Ошибка при установке software-properties-common." | tee -a "$LOG_FILE"; exit 1; }
    fi

    # Определение PSABI версии
    PSABI_VERSION=$(get_psabi_version)
    if [[ -z "$PSABI_VERSION" || ! "$PSABI_VERSION" =~ ^x64v[1-4]$ ]]; then
        echo "Ошибка: Некорректная версия PSABI: $PSABI_VERSION" | tee -a "$LOG_FILE"
        exit 1
    fi

    echo "Определена PSABI версия: $PSABI_VERSION" | tee -a "$LOG_FILE"

    # Выбор ветки обновлений
    while true; do
        read -p "Выберите ветку обновлений (1 - Main, 2 - Edge, 3 - LTS, 4 - RT): " branch_choice
        case $branch_choice in
            1) BRANCH="main"; break ;;
            2) BRANCH="edge"; break ;;
            3) BRANCH="lts"; break ;;
            4) BRANCH="rt"; break ;;
            *) echo "Пожалуйста, выберите 1, 2, 3 или 4." | tee -a "$LOG_FILE" ;;
        esac
    done

    # Формирование имени пакета
    if [[ $BRANCH == "main" ]]; then
        KERNEL_PACKAGE="linux-xanmod-$PSABI_VERSION"
    else
        KERNEL_PACKAGE="linux-xanmod-$BRANCH-$PSABI_VERSION"
    fi

    echo "Будет установлено ядро: $KERNEL_PACKAGE" | tee -a "$LOG_FILE"

    # Обновление списка пакетов
    echo "Обновление списка пакетов..." | tee -a "$LOG_FILE"
    apt update || { echo "Ошибка при обновлении списка пакетов." | tee -a "$LOG_FILE"; exit 1; }

    # Проверка наличия репозитория Xanmod
    if ! grep -q "^deb .*/xanmod/kernel" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
        echo "Добавление PPA репозитория Xanmod..." | tee -a "$LOG_FILE"
        add-apt-repository -y ppa:xanmod/kernel || { echo "Ошибка при добавлении репозитория." | tee -a "$LOG_FILE"; exit 1; }
        apt update || { echo "Ошибка при обновлении списка пакетов после добавления репозитория." | tee -a "$LOG_FILE"; exit 1; }
    fi

    # Установка выбранного ядра
    echo "Установка ядра $KERNEL_PACKAGE..." | tee -a "$LOG_FILE"
    apt install -y "$KERNEL_PACKAGE" || { echo "Ошибка при установке ядра." | tee -a "$LOG_FILE"; exit 1; }

    # Обновление GRUB
    echo "Обновление GRUB..." | tee -a "$LOG_FILE"
    update-grub || { echo "Ошибка при обновлении GRUB." | tee -a "$LOG_FILE"; exit 1; }

    # Сохранение состояния перед перезагрузкой
    echo "kernel_installed" > "$STATE_FILE"
}
# Функция для настройки TCP BBR
configure_bbr() {
    echo "Начало настройки TCP BBR..." | tee -a "$LOG_FILE"

    # Проверка наличия флага состояния
    if [[ ! -f "$STATE_FILE" || $(cat "$STATE_FILE") != "kernel_installed" ]]; then
        echo "Ядро еще не установлено. Завершение работы." | tee -a "$LOG_FILE"
        exit 1
    fi

    # Включение TCP BBR
    echo "Включение TCP BBR..." | tee -a "$LOG_FILE"
    cat <<EOF > /etc/sysctl.d/99-bbr.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

    sysctl --system || { echo "Ошибка при применении настроек sysctl." | tee -a "$LOG_FILE"; exit 1; }

    # Проверка статуса BBR
    echo "Проверка статуса TCP BBR..." | tee -a "$LOG_FILE"
    if [[ $(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}') == "bbr" ]]; then
        echo "TCP BBR успешно включен." | tee -a "$LOG_FILE"
    else
        echo "Ошибка: TCP BBR не включен." | tee -a "$LOG_FILE"
    fi

    # Проверка наличия BBR в очереди диска
    if [[ $(sysctl net.core.default_qdisc | awk '{print $3}') == "fq" ]]; then
        echo "Очередь диска 'fq' успешно настроена." | tee -a "$LOG_FILE"
    else
        echo "Ошибка: Очередь диска 'fq' не настроена." | tee -a "$LOG_FILE"
    fi

    # Удаление файла-флага
    rm -f "$STATE_FILE"
}

# Обработчик прерываний
cleanup() {
    echo "Скрипт был прерван. Очистка..." | tee -a "$LOG_FILE"
    rm -f "$STATE_FILE"
    exit 1
}
trap cleanup INT TERM

# Главная функция
main() {
    # Проверка наличия файла-флага
    if [[ -f "$STATE_FILE" && $(cat "$STATE_FILE") == "kernel_installed" ]]; then
        echo "Обнаружен файл-флаг. Продолжение настройки TCP BBR..." | tee -a "$LOG_FILE"
        configure_bbr
        exit 0
    fi

    # Установка ядра
    install_kernel

    # Перезагрузка системы
    read -p "Установка завершена. Хотите перезагрузить систему сейчас? (y/n): " reboot_choice
    if [[ $reboot_choice == "y" || $reboot_choice == "Y" ]]; then
        echo "Перезагрузка системы..." | tee -a "$LOG_FILE"
        reboot
    else
        echo "Не забудьте перезагрузить систему вручную для применения изменений." | tee -a "$LOG_FILE"
    fi
}

# Запуск главной функции
main