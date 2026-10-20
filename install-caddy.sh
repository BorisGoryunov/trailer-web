#!/usr/bin/env bash
# scp install-caddy.sh root@rathome.fvds.ru:/tmp/
# sudo bash /tmp/install-caddy.sh
# scp -r site/ root@80.74.27.126:/var/www/rathome/

set -euo pipefail

DOMAIN="${DOMAIN:-bg-k3s.ru}"
WEBROOT="${WEBROOT:-/var/www/rathome}"
LANDING="${LANDING:-pricep}"
CADDYFILE="/etc/caddy/Caddyfile"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERR\033[0m %s\n' "$*" >&2; exit 1; }

# --- 0. root check ---
if [ "$(id -u)" -ne 0 ]; then
  die "Запустите от root: sudo bash $0"
fi

# --- 1. distro check ---
if ! command -v apt-get >/dev/null 2>&1; then
  die "Скрипт рассчитан на Debian/Ubuntu (apt). Для других дистрибутивов поставьте Caddy вручную: https://caddyserver.com/docs/install"
fi

. /etc/os-release
log "Дистрибутив: ${PRETTY_NAME:-unknown}"

# --- 2. install Caddy ---
if command -v caddy >/dev/null 2>&1; then
  log "Caddy уже установлен: $(caddy version)"
else
  log "Устанавливаю Caddy из официального репозитория"
  apt-get update -y
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl gnupg

  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    > /etc/apt/sources.list.d/caddy-stable.list

  apt-get update -y
  apt-get install -y caddy

  log "Установлено: $(caddy version)"
fi

# --- 3. webroot ---
log "Готовлю каталог $WEBROOT/$LANDING"
mkdir -p "$WEBROOT/$LANDING"

# заглушка, чтобы Caddy не отдавал 404 до заливки лендинга
if [ ! -f "$WEBROOT/$LANDING/index.html" ]; then
  cat > "$WEBROOT/$LANDING/index.html" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>OK</title>
<h1>Сервер работает. Заливайте лендинг.</h1>
HTML
  warn "Положил заглушку в $WEBROOT/$LANDING/index.html — замените реальными файлами"
fi

# --- 4. Caddyfile ---
if [ -f "$CADDYFILE" ] && grep -q "$DOMAIN" "$CADDYFILE"; then
  log "Caddyfile уже содержит $DOMAIN — не трогаю"
else
  log "Пишу $CADDYFILE"
  # бэкап существующего
  [ -f "$CADDYFILE" ] && cp "$CADDYFILE" "$CADDYFILE.bak.$(date +%s)"
  cat > "$CADDYFILE" <<EOF
$DOMAIN {
    root * $WEBROOT
    encode gzip zstd
    file_server
}
EOF
fi

# --- 5. permissions ---
log "Права на $WEBROOT"
chown -R caddy:caddy "$WEBROOT"
chmod -R u=rwX,go=rX "$WEBROOT"

# --- 6. firewall ---
if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  log "Открываю 80/443 в ufw"
  ufw allow 80/tcp  >/dev/null || true
  ufw allow 443/tcp >/dev/null || true
else
  log "ufw не активен — пропускаю настройку фаервола"
fi

# --- 7. validate + reload ---
log "Проверяю конфиг"
caddy validate --config "$CADDYFILE" --adapter caddyfile

log "Перезапускаю Caddy"
systemctl enable --now caddy
systemctl restart caddy
sleep 1
systemctl --no-pager --full status caddy | head -n 15 || true

# --- 8. итог ---
log "Готово."
echo
echo "Проверьте:"
echo "  curl -I http://$DOMAIN/$LANDING/"
echo "  curl -I https://$DOMAIN/$LANDING/   # после выпуска сертификата, обычно 5-30 сек"
echo
echo "Логи Caddy:"
echo "  journalctl -u caddy -f"
echo
echo "DNS: убедитесь, что A-запись $DOMAIN указывает на IP этого VPS,"
echo "а порты 80/443 доступны извне (проверьте у провайдера)."