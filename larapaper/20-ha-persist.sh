#!/bin/sh
# Runs before 50-laravel-automations.sh (migrations, config cache).
# Moves persistent data into /config and applies the app's options to .env.
set -e

APP_DIR=/var/www/html
GENERATED="$APP_DIR/storage/app/public/images/generated"

mkdir -p /config/generated
[ -f /config/database.sqlite ] || touch /config/database.sqlite
chown -R www-data:www-data /config

if [ ! -L "$GENERATED" ]; then
    rm -rf "$GENERATED"
    ln -s /config/generated "$GENERATED"
fi

option() {
    php -r '$o = json_decode(file_get_contents("/data/options.json"), true); echo $o[$argv[1]] ?? "";' "$1"
}

set_env() {
    if grep -q "^$1=" "$APP_DIR/.env"; then
        sed -i "s|^$1=.*|$1=$2|" "$APP_DIR/.env"
    else
        echo "$1=$2" >> "$APP_DIR/.env"
    fi
}

APP_URL_OPT="$(option app_url)"
APP_KEY_OPT="$(option app_key)"
APP_PREVIOUS_KEYS_OPT="$(option app_previous_keys)"

[ -n "$APP_URL_OPT" ] && set_env APP_URL "$APP_URL_OPT"
[ -n "$APP_KEY_OPT" ] && set_env APP_KEY "$APP_KEY_OPT"
[ -n "$APP_PREVIOUS_KEYS_OPT" ] && set_env APP_PREVIOUS_KEYS "$APP_PREVIOUS_KEYS_OPT"

exit 0
