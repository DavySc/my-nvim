#!/bin/sh
# Run the smoke test and the startup budget in a throwaway XDG tree, so your
# own plugins, state and lua/local.lua stay out of it.
#   tests/run.sh                 # budget 60 ms (median of 7 starts)
#   BUDGET_MS=60 tests/run.sh    # slower machine
# NVIM_TEST_DATA=dir reuses installed plugins between runs.
set -eu
repo=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/config"
# A copy without lua/local.lua: the test runs against the defaults.
cp -R "$repo" "$tmp/config/nvim"
rm -f "$tmp/config/nvim/lua/local.lua"
export XDG_CONFIG_HOME="$tmp/config" XDG_STATE_HOME="$tmp/state" XDG_CACHE_HOME="$tmp/cache"
export XDG_DATA_HOME="${NVIM_TEST_DATA:-$tmp/data}"

# First start installs the plugins (vim.pack asks nothing in headless mode).
nvim --headless +'qa!' >/dev/null 2>&1 || true

nvim --headless -c "luafile $repo/tests/smoke.lua"
nvim --headless -c "luafile $repo/tests/multicursor_test.lua"
nvim --headless -c "luafile $repo/tests/reload_test.lua"

budget=${BUDGET_MS:-60}
times=""
for _ in 1 2 3 4 5 6 7; do
  rm -f "$tmp/st.log"
  nvim --headless --startuptime "$tmp/st.log" +'qa!' >/dev/null 2>&1
  times="$times $(awk '/NVIM STARTED/ { print $1 }' "$tmp/st.log")"
done
median=$(echo "$times" | tr ' ' '\n' | sed '/^$/d' | sort -n | sed -n 4p)
echo "startup: median ${median} ms (budget ${budget} ms; runs:${times})"
awk -v m="$median" -v b="$budget" 'BEGIN { exit (m + 0 <= b + 0) ? 0 : 1 }' || {
  echo "startup: over budget" >&2
  exit 1
}
