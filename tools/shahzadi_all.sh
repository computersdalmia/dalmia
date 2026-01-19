#!/usr/bin/env bash
# SHAHZADI ALL v4 — TITAN Diagnostic Engine (No secret leaks)
set -Eeuo pipefail
set +H
umask 022

TS="$(date +%F_%H-%M-%S)"
OUT_DIR="/var/backups/janu"
OUT="${OUT_DIR}/SHAHZADI_ALL_REPORT_${TS}.md"
TMP="${OUT_DIR}/.tmp_SHAHZADI_ALL_${TS}.md"
ERR="${OUT_DIR}/.tmp_SHAHZADI_ALL_${TS}.err"

mkdir -p "$OUT_DIR"
: > "$TMP"
: > "$ERR"

say(){ echo "[$(date +%F\ %T)] $*"; }
sec(){ echo; echo "## $*"; }
kv(){ printf -- "- **%s:** %s\n" "$1" "$2"; }

cmd_exists(){ command -v "$1" >/dev/null 2>&1; }
sh_try(){ bash -lc "$1" >>"$TMP" 2>>"$ERR" || true; }

trap 'echo; echo "NOTE: Non-fatal errors logged: '"$ERR"'" >>"'"$TMP"'"' ERR

# ---------- ROOT DETECTION ----------
APPROOT=""
for p in "/var/www/dalmia" "/var/www/janu" "/var/www/html" "/var/www" "/root/amit" "/root/Janu" "/var/amit" "/srv" "/opt"; do
  [ -d "$p" ] || continue
  if [ -f "$p/index.php" ] || [ -d "$p/public" ] || [ -d "$p/app" ] || [ -f "$p/composer.json" ]; then
    APPROOT="$p"; break
  fi
done

PUBROOT=""
for p in "/var/www/dalmia/public" "/var/www/janu/public" "/var/www/html" "/var/www/public" "/var/www/amit/public"; do
  [ -d "$p" ] && { PUBROOT="$p"; break; }
done

# ---------- HEADER ----------
{
  echo "# SHAHZADI ALL — Project JANU Live Audit (v4)"
  echo
  kv "Generated" "$TS"
  kv "Hostname" "$(hostname 2>/dev/null || true)"
  kv "OS" "$((lsb_release -ds 2>/dev/null || true) | head -n 1)"
  kv "Kernel" "$(uname -r 2>/dev/null || true)"
  kv "Uptime" "$(uptime -p 2>/dev/null || true)"
  kv "Disk /" "$(df -h / 2>/dev/null | awk "NR==2{print \$3\" used / \"\$2\" total (\" \$5 \")\"}" )"
  kv "APPROOT guess" "${APPROOT:-NOT_FOUND}"
  kv "PUBROOT guess" "${PUBROOT:-NOT_FOUND}"
} >>"$TMP"

# ---------- CORE STACK ----------
sec "Core services" >>"$TMP"
{
  kv "nginx installed" "$(cmd_exists nginx && echo YES || echo NO)"
  kv "nginx active" "$(systemctl is-active nginx 2>/dev/null || echo NO)"
  kv "php installed" "$(cmd_exists php && echo YES || echo NO)"
  kv "php version" "$(php -v 2>/dev/null | head -n1 || echo NA)"
  kv "php-fpm units" "$(systemctl list-units --type=service 2>/dev/null | awk "/php.*fpm/ {c++} END{print (c?c:0)}")"
  kv "php-fpm socket" "$(ls /run/php/php*-fpm.sock 2>/dev/null | head -n1 || echo NOT_FOUND)"
  if cmd_exists mariadb || cmd_exists mysql; then
    kv "mariadb/mysql installed" "YES"
  else
    kv "mariadb/mysql installed" "NO"
  fi
  kv "mariadb/mysql active" "$(systemctl is-active mariadb 2>/dev/null || systemctl is-active mysql 2>/dev/null || echo NO)"
} >>"$TMP"

# ---------- NGINX DEEP SCAN ----------
sec "Nginx sites enabled" >>"$TMP"
if [ -d /etc/nginx/sites-enabled ]; then
  sh_try 'ls -la /etc/nginx/sites-enabled 2>/dev/null | sed "s/^/- /"'
else
  echo "- /etc/nginx/sites-enabled not found" >>"$TMP"
fi

sec "Nginx vhost analysis (dalmia)" >>"$TMP"
if [ -f /etc/nginx/sites-available/dalmia ]; then
  sh_try 'echo "- server_name:"; grep -R "server_name" /etc/nginx/sites-available/dalmia'
  sh_try 'echo "- root:"; grep -R "root " /etc/nginx/sites-available/dalmia'
  sh_try 'echo "- ssl:"; grep -R "ssl_certificate" /etc/nginx/sites-available/dalmia'
  sh_try 'echo "- php socket:"; grep -R "fastcgi_pass" /etc/nginx/sites-available/dalmia'
else
  echo "- /etc/nginx/sites-available/dalmia not found" >>"$TMP"
fi

# ---------- SSL CHECK ----------
sec "SSL certificate status" >>"$TMP"
if cmd_exists openssl; then
  echo | openssl s_client -servername dalmiacomputers.in -connect dalmiacomputers.in:443 2>/dev/null \
    | openssl x509 -noout -dates 2>/dev/null >>"$TMP" || echo "- SSL check failed" >>"$TMP"
else
  echo "- openssl not installed" >>"$TMP"
fi

# ---------- DOMAIN ----------
sec "Domains quick check (HTTP codes)" >>"$TMP"
if cmd_exists curl; then
  for d in "dalmiacomputers.in" "www.dalmiacomputers.in"; do
    code="$(curl -sS -o /dev/null -w "%{http_code} (%{content_type})" "https://${d}" 2>/dev/null || echo curl_fail)"
    echo "- ${d} => ${code}" >>"$TMP"
  done
else
  echo "- curl not installed (skip)" >>"$TMP"
fi

# ---------- ENV + KEYS ----------
sec "Key files presence (no secrets printed)" >>"$TMP"
CANDS=()
for f in "${APPROOT}/.env" "${APPROOT}/app/.env" "${APPROOT}/config/.env" "/etc/janu/janu.env" "/var/www/dalmia/.env" "/var/www/.env"; do
  [ -f "$f" ] && CANDS+=("$f") && echo "- FOUND: $f" >>"$TMP"
done
[ "${#CANDS[@]}" -eq 0 ] && echo "- No env files found." >>"$TMP"

sec "Missing/placeholder keys scan (values NOT shown)" >>"$TMP"
if [ "${#CANDS[@]}" -eq 0 ]; then
  echo "- Skip: no env files." >>"$TMP"
else
  for f in "${CANDS[@]}"; do
    echo >>"$TMP"
    echo "### File: $f" >>"$TMP"
    awk -F= '
      /^[A-Za-z_][A-Za-z0-9_]*=/{
        var=$1; val=$0; sub(/^[^=]*=/,"",val);
        gsub(/[[:space:]]/,"",val);
        low=tolower(val);
        if (val=="" || val=="\"\"" || val=="'\'''\''" || low ~ /changeme|replace_me|todo|example|your_|xxxxx|dummy|testkey|<.*>/) {
          print "- " var " = (MISSING/PLACEHOLDER)"
        }
      }
    ' "$f" >>"$TMP" 2>>"$ERR" || true
  done
fi

sec "Integration checklist (presence by variable names only)" >>"$TMP"
if [ "${#CANDS[@]}" -gt 0 ]; then
  allvars="$(cat "${CANDS[@]}" 2>/dev/null | awk -F= "/^[A-Za-z_][A-Za-z0-9_]*=/{print \$1}" | sort -u || true)"
  kv "Gemini key" "$(echo "$allvars" | grep -Eqx "GEMINI_API_KEY|GOOGLE_API_KEY" && echo PRESENT || echo NO)" >>"$TMP"
  kv "Canva OAuth" "$(echo "$allvars" | grep -Eqx "CANVA_CLIENT_ID|CANVA_CLIENT_SECRET" && echo PRESENT || echo NO)" >>"$TMP"
  kv "MSG91" "$(echo "$allvars" | grep -Eqx "MSG91_AUTHKEY|MSG91_KEY|MSG91_API_KEY" && echo PRESENT || echo NO)" >>"$TMP"
  kv "Meta (FB/IG)" "$(echo "$allvars" | grep -Eqx "META_APP_ID|FB_APP_ID|FACEBOOK_APP_ID|META_APP_SECRET|FB_APP_SECRET|FACEBOOK_APP_SECRET" && echo PRESENT || echo NO)" >>"$TMP"
  kv "LinkedIn" "$(echo "$allvars" | grep -Eqx "LINKEDIN_CLIENT_ID|LINKEDIN_CLIENT_SECRET" && echo PRESENT || echo NO)" >>"$TMP"
  kv "SMTP" "$(echo "$allvars" | grep -Eqx "SMTP_HOST|SMTP_USER|SMTP_PASS|SMTP_PASSWORD" && echo PRESENT || echo NO)" >>"$TMP"
  kv "Google OAuth" "$(echo "$allvars" | grep -Eqx "GOOGLE_CLIENT_ID|GOOGLE_CLIENT_SECRET" && echo PRESENT || echo NO)" >>"$TMP"
else
  echo "- No env vars to detect integrations." >>"$TMP"
fi

# ---------- DATABASE ----------
sec "Database quick check (safe, names only)" >>"$TMP"
if cmd_exists mysql || cmd_exists mariadb; then
  echo "- Databases (names only):" >>"$TMP"
  (mysql -N -e "SHOW DATABASES;" 2>/dev/null || true) | sed "s/^/- /" >>"$TMP"
else
  echo "- mysql/mariadb not installed." >>"$TMP"
fi

# ---------- GIT ----------
sec "Git revision (APPROOT)" >>"$TMP"
if [ -d "${APPROOT}/.git" ]; then
  sh_try "cd '${APPROOT}' && git rev-parse --short HEAD"
  sh_try "cd '${APPROOT}' && git status --porcelain"
else
  echo "- APPROOT not a git repo" >>"$TMP"
fi

# ---------- AUTOMATION ----------
sec "Cron + systemd timers" >>"$TMP"
sh_try "crontab -l"
sh_try "systemctl list-timers --all | head -n 30"

# ---------- JANU MODULE DETECT ----------
sec "JANU module folders (heuristic)" >>"$TMP"
for d in "crm" "jobsheet" "kachcha_khata" "battery_advisor" "processor_advisor" "competitor_ai" "knowledge" "cinema" "geography" "referral" "contest"; do
  [ -d \"${APPROOT}/app/${d}\" ] && echo \"- FOUND: ${d}\" >>\"$TMP\"
done

# ---------- FINAL ----------
sec "Finalize" >>"$TMP"
echo "- Report saved to: $OUT" >>"$TMP"
[ -s "$ERR" ] && echo "- Non-fatal errors logged: $ERR" >>"$TMP"

mv -f "$TMP" "$OUT"
chmod 600 "$OUT" "$ERR" 2>/dev/null || true
say "OK: $OUT"
