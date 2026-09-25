#!/usr/bin/env bash
# Embed templates/ into src/agentinit.sh to produce the self-contained install.sh.
set -euo pipefail
cd "$(dirname "$0")"
out=install.sh
tmp=$(mktemp)
{
  awk '/^# @@TPL_BEGIN@@/ { exit } { print }' src/agentinit.sh
  echo '# Embedded by build.sh from templates/. Edit the templates, then run ./build.sh.'
  echo 'tpl() {'
  echo '  case "$1" in'
  find templates -name '*.md' | sort | while read -r f; do
    id=${f#templates/}; id=${id%.md}
    echo "    $id) cat <<'AGENTINIT_TPL'"
    cat "$f"
    [ -z "$(tail -c 1 "$f")" ] || echo
    echo "AGENTINIT_TPL"
    echo "    ;;"
  done
  echo '    *) die "unknown template: $1" ;;'
  echo '  esac'
  echo '}'
  awk 'f { print } /^# @@TPL_END@@/ { f = 1 }' src/agentinit.sh
} >"$tmp"
mv "$tmp" "$out"
chmod +x "$out"
echo "built $out ($(wc -l <"$out") lines)"
