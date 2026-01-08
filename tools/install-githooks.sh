#!/usr/bin/env bash
set -euo pipefail; set +H
umask 022
REPO="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO"

mkdir -p .githooks
cat > .githooks/pre-commit <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
fail(){ echo "BLOCKED: $*" >&2; exit 1; }

# Gate: bash syntax must pass for *.sh in server pack paths IF they exist on this machine
targets=()
[ -d /usr/local/bin ] && targets+=(/usr/local/bin)
[ -d /opt/janu-packs/dalmia/packs ] && targets+=(/opt/janu-packs/dalmia/packs)

for d in "${targets[@]}"; do
  while IFS= read -r f; do
    bash -n "$f" >/dev/null 2>&1 || fail "bash -n failed: $f"
  done < <(find "$d" -type f -name "*.sh" 2>/dev/null)
done

# Gate: no pasted HTML tags inside .sh
for d in "${targets[@]}"; do
  while IFS= read -r f; do
    if grep -qE "^[[:space:]]*<(script|link|div|li|style|html|head|body)\b" "$f"; then
      fail "pasted HTML tag detected in shell script: $f"
    fi
  done < <(find "$d" -type f -name "*.sh" 2>/dev/null)
done

exit 0
HOOK
chmod 755 .githooks/pre-commit
git config core.hooksPath .githooks
echo "OK: hooks installed (core.hooksPath=.githooks)"
