#!/usr/bin/env bash

# --- Функция: Выбор языка ---
select_language() {
    LANGUAGE=$(osascript <<EOF
        set user_language to button returned of (display dialog "Choose your language / Выберите ваш язык:" ¬
            buttons {"English", "Русский"} ¬
            default button "Русский" ¬
            with title "Ping Tool")
        return user_language
EOF
    )

    if [[ "$LANGUAGE" == "Русский" ]]; then
        LANG="ru"
    else
        LANG="en"
    fi
}

# --- Функция: Установка текстов интерфейса ---
set_texts() {
    if [[ "$LANG" == "ru" ]]; then
        TEXT_TITLE="Инструмент Ping"
        TEXT_ENTER_TARGET="Введите IP-адрес или домен:"
        TEXT_PING_TYPE="Выберите тип пинга:"
        TEXT_COUNT="Введите количество запросов (по умолчанию 4):"
        TEXT_TIMEOUT="Введите тайм-аут в секундах (по умолчанию 5):"
        TEXT_SUCCESS="Успех! Пинг выполнен успешно:\n\n"
        TEXT_ERROR="Ошибка! Пинг не удался:\n\n"
        TEXT_DNS_RESULT="Результат DNS-запроса:\n"
        TEXT_LOG="Результат сохранён в лог-файл:"
        BUTTON_OK="OK"
        BUTTON_CANCEL="Отмена"
        TYPE_IPV4="IPv4"
        TYPE_IPV6="IPv6"
    else
        TEXT_TITLE="Ping Tool"
        TEXT_ENTER_TARGET="Enter an IP address or domain:"
        TEXT_PING_TYPE="Choose ping type:"
        TEXT_COUNT="Enter the number of requests (default 4):"
        TEXT_TIMEOUT="Enter timeout in seconds (default 5):"
        TEXT_SUCCESS="Success! Ping completed successfully:\n\n"
        TEXT_ERROR="Error! Ping failed:\n\n"
        TEXT_DNS_RESULT="DNS Query Result:\n"
        TEXT_LOG="Result saved to log file:"
        BUTTON_OK="OK"
        BUTTON_CANCEL="Cancel"
        TYPE_IPV4="IPv4"
        TYPE_IPV6="IPv6"
    fi
}

# --- Функция: Валидация IP-адреса или доменного имени ---
validate_target() {
    local target="$1"
    if [[ "$target" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0  # IPv4
    elif [[ "$target" =~ ^[a-zA-Z0-9.-]+$ && "$target" != *..* && "$target" != -* && "$target" != *. ]]; then
        return 0  # Доменное имя
    else
        show_result "Ошибка: Некорректный ввод. Укажите правильный IP-адрес или доменное имя."
        exit 1
    fi
}

# --- Функция: Запрос у пользователя IP-адреса или домена ---
get_target() {
    osascript <<EOF
        set user_input to text returned of (display dialog "$TEXT_ENTER_TARGET" ¬
            default answer "" ¬
            with title "$TEXT_TITLE" ¬
            buttons {"$BUTTON_CANCEL", "$BUTTON_OK"} ¬
            default button "$BUTTON_OK")
        return user_input
EOF
}

# --- Функция: Запрос параметров пинга у пользователя ---
get_ping_params() {
    osascript <<EOF
        set ping_type to button returned of (display dialog "$TEXT_PING_TYPE" ¬
            buttons {"$TYPE_IPV6", "$TYPE_IPV4"} ¬
            default button "$TYPE_IPV4" ¬
            with title "$TEXT_TITLE")
        set ping_count to text returned of (display dialog "$TEXT_COUNT" ¬
            default answer "4" ¬
            with title "$TEXT_TITLE" ¬
            buttons {"$BUTTON_OK"} ¬
            default button "$BUTTON_OK")
        set ping_timeout to text returned of (display dialog "$TEXT_TIMEOUT" ¬
            default answer "5" ¬
            with title "$TEXT_TITLE" ¬
            buttons {"$BUTTON_OK"} ¬
            default button "$BUTTON_OK")
        return ping_type & "|" & ping_count & "|" & ping_timeout
EOF
}

# --- Функция: Отображение результата через osascript ---
show_result() {
    osascript <<EOF
        display dialog "$1" with title "$TEXT_TITLE" buttons {"$BUTTON_OK"} default button "$BUTTON_OK"
EOF
}

# --- Функция: Выполнение DNS-запроса ---
get_dns_name() {
    local target="$1"
    host "$target" 2>/dev/null | grep "domain name pointer" | awk '{print $5}'
}

# --- Функция: Запуск пинга ---
run_ping() {
    # 1. Выбор языка и установка текста
    select_language
    set_texts

    # 2. Получение цели пинга
    TARGET=$(get_target)
    if [[ -z "$TARGET" ]]; then
        show_result "Операция отменена пользователем." && exit 1
    fi

    # 3. Проверка корректности цели
    validate_target "$TARGET"

    # 4. Получение DNS-имени
    DNS_NAME=$(get_dns_name "$TARGET")
    if [[ -n "$DNS_NAME" ]]; then
        DNS_INFO="$TEXT_DNS_RESULT$DNS_NAME\n\n"
    else
        DNS_INFO=""
    fi

    # 5. Получение параметров пинга
    PING_PARAMS=$(get_ping_params)
    PING_TYPE=$(echo "$PING_PARAMS" | awk -F"|" '{print $1}')
    PING_COUNT=$(echo "$PING_PARAMS" | awk -F"|" '{print $2}')
    PING_TIMEOUT=$(echo "$PING_PARAMS" | awk -F"|" '{print $3}')

    # 6. Ограничение параметров
    ((PING_COUNT > 10)) && PING_COUNT=10
    ((PING_TIMEOUT < 1 || PING_TIMEOUT > 60)) && PING_TIMEOUT=5

    # 7. Формирование команды
    if [[ "$PING_TYPE" == "$TYPE_IPV6" ]]; then
        PING_COMMAND="ping6 -c $PING_COUNT -W $PING_TIMEOUT $TARGET"
    else
        PING_COMMAND="ping -c $PING_COUNT -W $PING_TIMEOUT $TARGET"
    fi

    # 8. Выполнение команды
    RESULT=$($PING_COMMAND 2>&1)
    if [[ $? -eq 0 ]]; then
        show_result "$DNS_INFO$TEXT_SUCCESS$RESULT"
    else
        show_result "$DNS_INFO$TEXT_ERROR$RESULT"
    fi

    # 9. Логирование результата
    log_result
}

# --- Функция: Запись результатов в лог-файл ---
log_result() {
    LOGFILE="/var/log/ping_tool.log"
    mkdir -p "$(dirname "$LOGFILE")"
    umask 077
    echo "[$(date)] Target: $TARGET, Command: $PING_COMMAND" >> "$LOGFILE"
    echo "$RESULT" >> "$LOGFILE"
    show_result "$TEXT_LOG $LOGFILE"
}

# --- Функция main, вызывающая все необходимые процессы ---
main() {
    run_ping
}

# Запуск скрипта
main

