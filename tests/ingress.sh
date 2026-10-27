#!/bin/bash
# Exercises larapaper/app/HomeAssistant against the built image with Apple's `container` CLI, on a
# network shaped like the Supervisor's, where the ingress proxy is 172.30.32.2.
#
#   container system start
#   tests/ingress.sh
#
# `container` can't pin IPs, but hands them out in order on a new network, so the ingress probe is
# started first and the run stops if it didn't get .2.
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE=larapaper-test
NET=larapaper-test
CURL=curlimages/curl:8.11.1
PREFIX=/api/hassio_ingress/testtoken
HOST=ha.example
PORT=14567 # host port standing in for 4567

# config.yaml's environment block as KEY=value lines.
app_env() {
    awk '/^environment:/ { on = 1; next } /^[^ ]/ { on = 0 }
        on && /^  [A-Z_]+:/ { sub(/^  /, ""); sub(/: /, "="); gsub(/"/, ""); print }' larapaper/config.yaml
}
INGRESS_IP=172.30.32.2
failed=0

cleanup() {
    container rm -f ingress other app cfmode >/dev/null 2>&1 || true
    container network rm "$NET" >/dev/null 2>&1 || true
}
cleanup
trap cleanup EXIT

ip_of() { # container
    container inspect "$1" | python3 -c \
        'import json, sys; print(json.load(sys.stdin)[0]["status"]["networks"][0]["ipv4Address"].split("/")[0])'
}

probe() { # name
    container run -d --name "$1" --network "$NET" --entrypoint sleep "$CURL" infinity >/dev/null
}

start() { # name trusted_proxy [run args...]
    local name=$1 trusted_proxy=$2 data env=()
    shift 2
    data=$(mktemp -d)
    echo '{"app_url": "http://localhost", "ingress_login": "admin@example.com", "ingress_ha_user": "reed"}' \
        >"$data/options.json"
    while IFS= read -r line; do env+=(-e "$line"); done < <(app_env | grep -v '^TRUSTED_PROXY=')
    container run -d --name "$name" --network "$NET" "${env[@]}" -e "TRUSTED_PROXY=$trusted_proxy" \
        -v "$data:/data" "$@" "$IMAGE" >/dev/null
}

wait_ready() { # app_ip
    for _ in $(seq 120); do
        container exec other curl -fsS -o /dev/null "http://$1:8080/up" 2>/dev/null && return
        sleep 2
    done
    echo "App at $1 never came up"
    container logs app 2>&1 | tail -40
    exit 1
}

add_user() { # container
    container exec -u www-data -w /var/www/html "$1" php -r '
        require "vendor/autoload.php";
        $app = require "bootstrap/app.php";
        $app->make(Illuminate\Contracts\Console\Kernel::class)->bootstrap();
        App\Models\User::create(["name" => "Admin", "email" => "admin@example.com", "password" => "unused-password"]);'
}

BODY=$(mktemp)

# Prints "<status> <redirect url>" and saves the body to $BODY.
request() { # probe url [curl args...]
    local probe=$1 url=$2
    shift 2
    container exec "$probe" curl -sS -o /tmp/body -w '%{http_code} %{redirect_url}' "$@" "$url"
    container exec "$probe" cat /tmp/body >"$BODY"
}

check() { # description actual expected-glob
    # shellcheck disable=SC2053
    if [[ $2 == $3 ]]; then
        echo "PASS  $1"
    else
        echo "FAIL  $1: expected '$3', got '$2'"
        failed=1
    fi
}

# As HA sends them when it's behind Cloudflare, which adds CF-Connecting-IP and HA passes it through.
ingress_headers=(-H "X-Ingress-Path: $PREFIX" -H "X-Forwarded-Host: $HOST" -H "X-Forwarded-Proto: https"
    -H "X-Forwarded-For: 203.0.113.7, 172.30.32.1" -H "CF-Connecting-IP: 203.0.113.7")
spoof_headers=(-H "X-Ingress-Path: $PREFIX" -H "X-Remote-User-Name: reed" -H "CF-Connecting-IP: $INGRESS_IP"
    -H "X-Forwarded-For: $INGRESS_IP")

container build -t "$IMAGE" larapaper
container network create --subnet 172.30.32.0/23 "$NET" >/dev/null

probe ingress
if [[ $(ip_of ingress) != "$INGRESS_IP" ]]; then
    echo "The ingress probe got $(ip_of ingress), not $INGRESS_IP; can't test"
    exit 1
fi
probe other # stands in for the Tailscale app or any other app on the Supervisor network

start app "$(app_env | sed -n 's/^TRUSTED_PROXY=//p')" -p "127.0.0.1:$PORT:8080"
start cfmode cloudflare # the image's default nginx mode, to show the spoof checks can catch the hole
APP=$(ip_of app)
CFMODE=$(ip_of cfmode)
wait_ready "$APP"
wait_ready "$CFMODE"
add_user app
add_user cfmode

echo "Ingress, as the configured HA user"
check "logged in automatically" \
    "$(request ingress "http://$APP:8080/dashboard" "${ingress_headers[@]}" -H "X-Remote-User-Name: reed")" "200 "
asset=$(grep -o "https://$HOST$PREFIX/build/assets/[^\"]*" "$BODY" | head -1 || true)
check "Vite assets use the ingress path" "$asset" "https://$HOST$PREFIX/build/assets/*"
check "Livewire posts to the ingress path" "$(grep -o 'data-update-uri="[^"]*"' "$BODY" || true)" \
    "data-update-uri=\"https://$HOST$PREFIX/*\""
check "assets load once HA strips the prefix" \
    "$([[ -n $asset ]] && request ingress "http://$APP:8080${asset#https://$HOST$PREFIX}")" "200 "

echo "Ingress, as another HA user"
check "sent to the prefixed login page" \
    "$(request ingress "http://$APP:8080/dashboard" "${ingress_headers[@]}" -H "X-Remote-User-Name: guest")" \
    "302 https://$HOST$PREFIX/login"

echo "Spoofed ingress headers"
check "from another app (e.g. Tailscale): not logged in, no prefix" \
    "$(request other "http://$APP:8080/dashboard" "${spoof_headers[@]}")" "302 http://$APP:8080/login"
check "from the LAN via the published port: not logged in, no prefix" \
    "$(curl -sS -o /dev/null -w '%{http_code} %{redirect_url}' "${spoof_headers[@]}" "http://127.0.0.1:$PORT/dashboard")" \
    "302 http://127.0.0.1:$PORT/login"
check "control: with nginx in \"cloudflare\" mode, the same spoof gets in" \
    "$(request other "http://$CFMODE:8080/dashboard" "${spoof_headers[@]}")" "200 "

echo "Direct access on the published port"
check "login page has unprefixed links" \
    "$(curl -sS -o "$BODY" -w '%{http_code}' "http://127.0.0.1:$PORT/login") $(grep -c hassio_ingress "$BODY" || true)" \
    "200 0"

exit $failed
