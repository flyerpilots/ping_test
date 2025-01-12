#!/bin/bash

# Локализация: определяем язык интерфейса (русский/английский)
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

# Устанавливаем текстовые сообщения в зависимости от языка
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

# Получаем цель (IP или домен)
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

# Выбираем параметры пинга
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

# Показываем результат
show_result() {
    osascript <<EOF
        display dialog "$1" with title "$TEXT_TITLE" buttons {"$BUTTON_OK"} default button "$BUTTON_OK"
EOF
}

# Получение DNS-имени (обратный поиск)
get_dns_name() {
    local target="$1"
    host "$target" 2>/dev/null | grep "domain name pointer" | awk '{print $5}'
}

# Выбираем язык
select_language
set_texts

# Получаем цель
TARGET=$(get_target)

# Если пользователь отменил ввод
if [[ -z "$TARGET" ]]; then
    show_result "Операция отменена пользователем." && exit 1
fi

# Проверяем, введён ли IP-адрес или доменное имя
DNS_NAME=$(get_dns_name "$TARGET")
if [[ -n "$DNS_NAME" ]]; then
    DNS_INFO="$TEXT_DNS_RESULT$DNS_NAME\n\n"
else
    DNS_INFO=""
fi

# Получаем параметры пинга
PING_PARAMS=$(get_ping_params)
PING_TYPE=$(echo "$PING_PARAMS" | awk -F"|" '{print $1}')
PING_COUNT=$(echo "$PING_PARAMS" | awk -F"|" '{print $2}')
PING_TIMEOUT=$(echo "$PING_PARAMS" | awk -F"|" '{print $3}')

# Выбор команды пинга
if [[ "$PING_TYPE" == "$TYPE_IPV6" ]]; then
    PING_COMMAND="ping6 -c $PING_COUNT -W $PING_TIMEOUT $TARGET"
else
    PING_COMMAND="ping -c $PING_COUNT -W $PING_TIMEOUT $TARGET"
fi

# Выполняем пинг
RESULT=$($PING_COMMAND 2>&1)

# Проверка результата
if [[ $? -eq 0 ]]; then
    show_result "$DNS_INFO$TEXT_SUCCESS$RESULT"
else
    show_result "$DNS_INFO$TEXT_ERROR$RESULT"
fi

# Логируем результат
LOGFILE="ping_tool.log"
echo "[$(date)] Target: $TARGET, Command: $PING_COMMAND" >> "$LOGFILE"
echo "$RESULT" >> "$LOGFILE"
show_result "$TEXT_LOG $LOGFILE"

