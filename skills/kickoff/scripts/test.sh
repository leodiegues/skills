#!/usr/bin/env bash
# Self-check for launch.sh against stub host CLIs in a throwaway directory.
set -euo pipefail
lnch="$(cd "$(dirname "$0")" && pwd)/launch.sh"
tmp=$(cd "$(mktemp -d)" && pwd -P); trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir "$tmp/bin"
# Stub wt: returns a fake worktree path.
cat > "$tmp/bin/wt" <<EOF
#!/bin/sh
echo "wt \$*" >> "$tmp/calls.log"
printf '{"path":"%s/wt/%s"}\n' "$tmp" "\$2"
EOF
# Stub hc: logs argv (one arg per line to hc-argv.log) and returns a fake terminal address.
cat > "$tmp/bin/hc" <<EOF
#!/bin/sh
printf '%s\n' "\$@" > "$tmp/hc-argv.log"
if [ "\$1" = get ]; then printf '{"labels":{"herdr.space":"sp0"}}\n'; exit 0; fi
printf '{"address":"t14"}\n'
EOF
# Stub herdr-app: ls succeeds when $tmp/window exists; do space.new logs payload and returns ids.
cat > "$tmp/bin/herdr-app" <<EOF
#!/bin/sh
if [ "\$1" = ls ]; then [ -f "$tmp/window" ] || exit 1; printf '{"spaces":[]}\n'; exit 0; fi
printf '%s\n' "\$3" > "$tmp/space-new.json"
printf '{"space":"sp2","tab":"tab1","terminal":"t20"}\n'
EOF
# Stub claude, codex, agy, rex, herdr, t3.
for b in claude codex agy rex herdr t3; do
  printf '#!/bin/sh\n' > "$tmp/bin/$b"
done
chmod +x "$tmp/bin/"*

run() {
  local envs=()
  while [ $# -gt 0 ] && [ "$1" != -- ]; do envs+=("$1"); shift; done
  [ "${1:-}" != -- ] || shift
  env -u T3CODE_THREAD_ID -u T3CODE_CLI_PATH -u HERDR_ENV -u HERDR_WORKSPACE_ID \
      -u REX_SESSION -u HC_TERMINAL_ID -u CODEX_THREAD_ID -u OPENCODE -u CLAUDECODE \
      -u ANTIGRAVITY_AGENT \
      PATH="$tmp/bin:$PATH" "${envs[@]}" "$lnch" "$@"
}

# --host detects hc with terminal and cli, and respects innermost-host precedence.
out=$(run HC_TERMINAL_ID=t5 CLAUDECODE=1 -- --host)
[ "$(jq -c '[.provider, .terminal, .cli]' <<<"$out")" = '["hc","t5","claude"]' ] || fail "--host hc: $out"

out=$(run HC_TERMINAL_ID=t5 REX_SESSION=s1 CLAUDECODE=1 -- --host)
[ "$(jq -c '[.provider, .terminal, .cli]' <<<"$out")" = '["rex",null,"claude"]' ] || fail "--host rex precedence: $out"

out=$(run HC_TERMINAL_ID=t5 T3CODE_THREAD_ID=th1 -- --host)
[ "$(jq -c '[.provider, .terminal, .cli]' <<<"$out")" = '["t3",null,null]' ] || fail "--host t3 precedence: $out"

out=$(run HC_TERMINAL_ID=t5 ANTIGRAVITY_AGENT=1 -- --host)
[ "$(jq -c '[.provider, .terminal, .cli]' <<<"$out")" = '["hc","t5","agy"]' ] || fail "--host agy: $out"

# hc with --parent: nests under HC_TERMINAL_ID, names terminal after branch, passes Claude --name label.
touch "$tmp/window"
out=$(printf 'implement EVE-2719' | run HC_TERMINAL_ID=t5 CLAUDECODE=1 -- --parent --label "EVE-2719 build" eve-2719-build)
[ "$(jq -c '[.provider, .branch, .terminal, .name, .parent, .space_id, .tab_id, .cli]' <<<"$out")" \
  = '["hc","eve-2719-build","t14","eve-2719-build","t5",null,null,"claude"]' ] || fail "hc --parent output: $out"
grep -qx -- '--parent' "$tmp/hc-argv.log" || fail "hc --parent flag missing"
grep -qx -- 't5' "$tmp/hc-argv.log" || fail "hc --parent value missing"
grep -qx -- '--name' "$tmp/hc-argv.log" || fail "hc --name missing"
grep -qx -- 'eve-2719-build' "$tmp/hc-argv.log" || fail "hc terminal name missing"
grep -qx -- '--outlive-parent' "$tmp/hc-argv.log" || fail "hc --outlive-parent missing"
grep -qx -- 'EVE-2719 build' "$tmp/hc-argv.log" || fail "claude --name label missing"

# hc without --parent (window open): opens separate space via herdr-app space.new, parent and name are null.
out=$(printf 'implement EVE-2720' | run HC_TERMINAL_ID=t5 CLAUDECODE=1 -- --label "EVE-2720 build" eve-2720-build)
[ "$(jq -c '[.provider, .branch, .terminal, .name, .parent, .space_id, .tab_id, .cli]' <<<"$out")" \
  = '["hc","eve-2720-build","t20",null,null,"sp2","tab1","claude"]' ] || fail "hc space.new output: $out"
[ "$(jq -c '.argv' "$tmp/space-new.json")" \
  = '["claude","--dangerously-skip-permissions","--name","EVE-2720 build","implement EVE-2720"]' ] || fail "hc space.new argv: $(cat "$tmp/space-new.json")"

# agy uses --dangerously-skip-permissions and --prompt-interactive for the kickoff prompt.
out=$(printf 'implement EVE-2721' | run HC_TERMINAL_ID=t5 ANTIGRAVITY_AGENT=1 -- --label "EVE-2721 build" eve-2721-build)
[ "$(jq -c '[.provider, .branch, .cli]' <<<"$out")" = '["hc","eve-2721-build","agy"]' ] || fail "hc agy output: $out"
[ "$(jq -c '.argv' "$tmp/space-new.json")" \
  = '["agy","--dangerously-skip-permissions","--prompt-interactive","implement EVE-2721"]' ] || fail "hc agy argv: $(cat "$tmp/space-new.json")"

# hc without --parent and no window open: headless fallback uses --no-parent and inherits herdr.space.
rm "$tmp/window"
out=$(printf 'implement headless' | run HC_TERMINAL_ID=t5 CLAUDECODE=1 -- headless-branch)
[ "$(jq -c '[.provider, .branch, .terminal, .name, .parent, .space_id, .tab_id, .cli]' <<<"$out")" \
  = '["hc","headless-branch","t14",null,null,"sp0",null,"claude"]' ] || fail "hc headless output: $out"
grep -qx -- '--no-parent' "$tmp/hc-argv.log" || fail "hc headless --no-parent missing"
grep -qx -- 'herdr.space=sp0' "$tmp/hc-argv.log" || fail "hc headless space label missing"

# Missing option argument fails cleanly.
if err=$(run HC_TERMINAL_ID=t5 CLAUDECODE=1 -- --label 2>&1); then
  fail "missing --label arg not refused"
fi
case "$err" in *"--label requires text"*) ;; *) fail "wrong missing --label error: $err" ;; esac

# --parent rejected on non-hc host.
if err=$(printf 'go' | run REX_SESSION=s1 CLAUDECODE=1 -- --parent feat 2>&1); then
  fail "--parent on rex not refused"
fi
case "$err" in *"--parent needs a Herdr app"*) ;; *) fail "wrong --parent error: $err" ;; esac

echo ok
