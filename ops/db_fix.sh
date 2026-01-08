#!/usr/bin/env bash
set -euo pipefail
set +H

ts() { date "+%F_%H%M%S"; }

TS="$(ts)"
BK="/var/backups/janu/DB_FIX_CLEAN_${TS}"
mkdir -p "$BK"
chmod 700 "$BK"
echo "BK: $BK"

echo "== 0) Hard stop + kill ALL mariadbd/mysqld (including temp sockets) =="
systemctl stop mariadb 2> /dev/null || true
pkill -9 -x mariadbd 2> /dev/null || true
pkill -9 -x mysqld 2> /dev/null || true
pkill -9 -f mysqld_safe 2> /dev/null || true
sleep 2

echo "== 1) Clean runtime dirs + temp sockets =="
rm -f /tmp/janu.sock /tmp/janu.pid /tmp/janu.err 2> /dev/null || true
rm -f /run/mysqld/mysqld.sock /run/mysqld/mysqld.pid 2> /dev/null || true
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
chmod 755 /run/mysqld

echo "== 2) Backup + reset Aria logs (safe) =="
cd /var/lib/mysql
for f in aria_log_control aria_log.*; do
  [ -e "$f" ] && cp -a "$f" "$BK/" || true
done
rm -f aria_log_control aria_log.* 2> /dev/null || true
rm -f ibtmp1 2> /dev/null || true
chown -R mysql:mysql /var/lib/mysql

echo "== 3) Start TEMP mariadbd (skip grants) on /tmp/janu.sock =="
sudo -u mysql /usr/sbin/mariadbd \
  --no-defaults \
  --datadir=/var/lib/mysql \
  --skip-grant-tables \
  --skip-networking \
  --port=0 \
  --socket=/tmp/janu.sock \
  --pid-file=/tmp/janu.pid \
  --log-error=/tmp/janu.err \
  > /dev/null 2>&1 &

for i in $(seq 1 60); do
  [ -S /tmp/janu.sock ] && break
  sleep 1
done
if [ ! -S /tmp/janu.sock ]; then
  echo "FAIL: temp socket not created"
  tail -n 200 /tmp/janu.err || true
  exit 1
fi

SQL="mariadb --no-defaults --protocol=socket --socket=/tmp/janu.sock -uroot"

echo "== 4) TEMP connect ok =="
$SQL -e "SELECT \"temp_ok\" s, VERSION() v, USER() u, CURRENT_USER() cu;" | cat

echo "== 5) Rebuild root (unix_socket) + debian-sys-maint (fresh) =="
PASS="$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 32)"
echo "$PASS" > "$BK/debian_sys_maint_pass.txt"
chmod 600 "$BK/debian_sys_maint_pass.txt"

# These statements run under skip-grant-tables, so no privilege checks
$SQL -e "
FLUSH PRIVILEGES;

CREATE USER IF NOT EXISTS root@localhost IDENTIFIED VIA unix_socket;
ALTER USER root@localhost IDENTIFIED VIA unix_socket;
GRANT ALL PRIVILEGES ON *.* TO root@localhost WITH GRANT OPTION;

CREATE USER IF NOT EXISTS debian-sys-maint@localhost IDENTIFIED BY ;
ALTER USER debian-sys-maint@localhost IDENTIFIED BY ;
GRANT ALL PRIVILEGES ON *.* TO debian-sys-maint@localhost WITH GRANT OPTION;

FLUSH PRIVILEGES;
" | cat

echo "== 6) Write /etc/mysql/debian.cnf (correct) =="
cat > /etc/mysql/debian.cnf << EOF
[client]
host     = localhost
user     = debian-sys-maint
password = ${PASS}
socket   = /run/mysqld/mysqld.sock
EOF
chmod 600 /etc/mysql/debian.cnf

echo "== 7) Stop TEMP mariadbd cleanly =="
if [ -f /tmp/janu.pid ]; then
  kill "$(cat /tmp/janu.pid)" 2> /dev/null || true
  sleep 2
fi
pkill -9 -x mariadbd 2> /dev/null || true
rm -f /tmp/janu.sock /tmp/janu.pid /tmp/janu.err 2> /dev/null || true
sleep 1

echo "== 8) Start normal MariaDB =="
systemctl start mariadb
sleep 2
systemctl is-active mariadb > /dev/null || {
  echo "FAIL: mariadb still not active"
  systemctl --no-pager -l status mariadb | tail -n 80 || true
  journalctl -xeu mariadb --no-pager | tail -n 120 || true
  exit 1
}

echo "== 9) Verify root socket login works =="
mariadb --protocol=socket -uroot -e "SELECT \"root_ok\" s, USER() u, CURRENT_USER() cu, VERSION() v;" | cat

echo "== 10) Verify debian-sys-maint works =="
mariadb --defaults-extra-file=/etc/mysql/debian.cnf --protocol=socket -e "SELECT \"maint_ok\" s, USER() u, CURRENT_USER() cu;" | cat

echo "DONE ✅  (BK: $BK)"
