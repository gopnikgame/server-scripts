#!/bin/bash

set -euo pipefail

# Константы
readonly STATE_FILE="/var/tmp/xanmod_install_state"
readonly LOG_FILE="/var/log/xanmod_install.log"
readonly SYSCTL_CONFIG="/etc/sysctl.d/99-bbr.conf"

# Функция логирования
log() {
    local message="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$LOG_FILE"
}

# Функция для обновления системы
system_update() {
    log "Начало обновления системы..."
    apt-get update || { log "Ошибка при выполнении apt-get update"; exit 1; }
    apt-get upgrade -y || { log "Ошибка при выполнении apt-get upgrade"; exit 1; }
    apt-get dist-upgrade -y || { log "Ошибка при выполнении apt-get dist-upgrade"; exit 1; }
    apt-get autoclean -y || { log "Ошибка при выполнении apt-get autoclean"; exit 1; }
    apt-get autoremove -y || { log "Ошибка при выполнении apt-get autoremove"; exit 1; }
    log "Обновление системы завершено успешно"
}

# Функция для очистки системы
system_cleanup() {
    log "Начало очистки системы..."
    apt-get autoremove --purge -y || { log "Ошибка при выполнении apt-get autoremove --purge"; exit 1; }
    log "Очистка системы завершена успешно"
}

# Функция проверки зависимостей
check_dependencies() {
    local deps=(awk grep add-apt-repository apt-get)
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

[предыдущие функции остаются без изменений...]

# Функция для установки ядра
install_kernel() {
    log "Начало процесса установки ядра..."
    
    # Обновление системы перед установкой
    log "Выполнение полного обновления системы перед установкой ядра..."
    system_update
    
    log "Система обновлена. Требуется перезагрузка перед продолжением установки."
    echo "update_complete" > "$STATE_FILE"
    
    echo -e "\n\033[1;33mВНИМАНИЕ!\033[0m"
    echo "Система была обновлена и требует перезагрузки."
    echo "После перезагрузки, пожалуйста, запустите скрипт снова для продолжения установки."
    
    read -p "Нажмите Enter для перезагрузки системы..."
    reboot
}

# Главная функция
main() {
    # Инициализация
    check_root
    check_os
    check_dependencies

    # Проверка состояния установки
    if [[ -f "$STATE_FILE" ]]; then
        case $(cat "$STATE_FILE") in
            "update_complete")
                log "Продолжение установки после обновления системы..."
                rm -f "$STATE_FILE"
                
                # Продолжение установки ядра
                log "Начало установки ядра Xanmod..."
                [оригинальный код установки ядра]
                
                echo "kernel_installed" > "$STATE_FILE"
                
                echo -e "\n\033[1;33mВНИМАНИЕ!\033[0m"
                echo "Ядро Xanmod успешно установлено. Требуется перезагрузка."
                echo "После перезагрузки, пожалуйста, запустите скрипт снова для настройки BBR3."
                
                read -p "Нажмите Enter для перезагрузки системы..."
                reboot
                ;;
                
            "kernel_installed")
                log "Начало настройки TCP BBR..."
                configure_bbr
                
                # Очистка системы после всех установок
                log "Выполнение финальной очистки системы..."
                system_cleanup
                
                log "Установка и настройка успешно завершены!"
                rm -f "$STATE_FILE"
                exit 0
                ;;
        esac
    else
        # Начало процесса установки
        install_kernel
    fi
}

# Установка обработчиков сигналов
trap cleanup INT TERM QUIT

# Запуск главной функции
main