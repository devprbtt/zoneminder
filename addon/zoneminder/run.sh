#!/usr/bin/env bash
set -euo pipefail

OPTIONS_FILE="/data/options.json"
MYSQL_DATADIR="/data/mysql"
MYSQL_SOCKET="/run/mysqld/mysqld.sock"
APACHE_PORT="8088"

read_opt() {
  local key="$1"
  local default="$2"
  local value=""

  if [[ -f "${OPTIONS_FILE}" ]]; then
    value="$(jq -r --arg key "${key}" '.[$key] // empty' "${OPTIONS_FILE}")"
  else
    value=""
  fi

  if [[ -z "${value}" ]]; then
    echo "${default}"
    return 0
  fi

  echo "${value}"
}

DB_NAME="$(read_opt db_name zm)"
DB_USER="$(read_opt db_user zmuser)"
DB_PASS="$(read_opt db_pass zmsecret)"
DB_ROOT_PASS="$(read_opt db_root_pass rootsecret)"
TIMEZONE="$(read_opt timezone UTC)"
EVENTS_DIR="$(read_opt events_path /data/events)"

export TZ="${TIMEZONE}"

mkdir -p "${MYSQL_DATADIR}" "${EVENTS_DIR}" /run/mysqld /var/cache/zoneminder /var/log/zm
chown -R mysql:mysql "${MYSQL_DATADIR}" /run/mysqld

if [[ ! -d "${MYSQL_DATADIR}/mysql" ]]; then
  mariadb-install-db --user=mysql --datadir="${MYSQL_DATADIR}" >/dev/null
fi

mysqld_safe --datadir="${MYSQL_DATADIR}" --socket="${MYSQL_SOCKET}" --pid-file=/run/mysqld/mysqld.pid &

for _ in $(seq 1 60); do
  if mysqladmin --socket="${MYSQL_SOCKET}" ping --silent >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

mysql --socket="${MYSQL_SOCKET}" -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';" || true
mysql --socket="${MYSQL_SOCKET}" -uroot -p"${DB_ROOT_PASS}" -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;"
mysql --socket="${MYSQL_SOCKET}" -uroot -p"${DB_ROOT_PASS}" -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql --socket="${MYSQL_SOCKET}" -uroot -p"${DB_ROOT_PASS}" -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"

if ! mysql --socket="${MYSQL_SOCKET}" -uroot -p"${DB_ROOT_PASS}" -D "${DB_NAME}" -e "SELECT 1 FROM Config LIMIT 1;" >/dev/null 2>&1; then
  mysql --socket="${MYSQL_SOCKET}" -uroot -p"${DB_ROOT_PASS}" "${DB_NAME}" < /usr/share/zoneminder/db/zm_create.sql
fi

if [[ -f /etc/zm/zm.conf ]]; then
  chown root:www-data /etc/zm/zm.conf || true
  chmod 644 /etc/zm/zm.conf || true
fi

mkdir -p /etc/zm/conf.d
cat > /etc/zm/conf.d/99-addon.conf <<EOF
ZM_DB_HOST=localhost
ZM_DB_NAME=${DB_NAME}
ZM_DB_USER=${DB_USER}
ZM_DB_PASS=${DB_PASS}
EOF
chown root:www-data /etc/zm/conf.d/99-addon.conf || true
chmod 644 /etc/zm/conf.d/99-addon.conf || true

# Keep host port 80 free for other services by moving Apache to a fixed port.
if [[ -f /etc/apache2/ports.conf ]]; then
  sed -i -E "s/^Listen[[:space:]]+[0-9]+$/Listen ${APACHE_PORT}/" /etc/apache2/ports.conf
fi
if [[ -d /etc/apache2/sites-available ]]; then
  sed -i -E "s/<VirtualHost \\*:80>/<VirtualHost *:${APACHE_PORT}>/g" /etc/apache2/sites-available/*.conf || true
fi
if [[ -d /etc/apache2/sites-enabled ]]; then
  sed -i -E "s/<VirtualHost \\*:80>/<VirtualHost *:${APACHE_PORT}>/g" /etc/apache2/sites-enabled/*.conf || true
fi

if [[ -L /var/cache/zoneminder/events || -d /var/cache/zoneminder/events ]]; then
  rm -rf /var/cache/zoneminder/events
fi
ln -s "${EVENTS_DIR}" /var/cache/zoneminder/events
chown -R www-data:www-data /var/cache/zoneminder "${EVENTS_DIR}" || true

zmpkg.pl start

cleanup() {
  zmpkg.pl stop || true
  mysqladmin --socket="${MYSQL_SOCKET}" -uroot -p"${DB_ROOT_PASS}" shutdown || true
}

trap cleanup EXIT INT TERM

exec apache2ctl -D FOREGROUND
