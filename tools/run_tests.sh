#!/usr/bin/env bash
# Runs every headless test in tests/ and prints a pass/fail summary.
# Backs up and restores the user save (tests write user://save.tres) and
# restores the git plugin dll that Godot touches.
#   bash tools/run_tests.sh            # all tests
#   bash tools/run_tests.sh stats map  # only tests whose name contains a word
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/c/Users/kyleo/OneDrive/Desktop/Godot_v4.5.1-stable_win64.exe}"
SAVE_DIR="$APPDATA/Godot/app_userdata/Dice RPG Game 2026"
BACKUP="$(mktemp -d)"
[ -f "$SAVE_DIR/save.tres" ] && cp "$SAVE_DIR/save.tres" "$BACKUP/save.tres"

pass=0; fail=0; failed=()
run_one() {
	local name="$1"; shift
	local log="$BACKUP/$name.log"
	timeout 600 "$GODOT" --headless --path . "$@" >"$log" 2>&1
	local code=$?
	rm -f "$SAVE_DIR/save.tres"
	# The editor round-trip test runs editor plugins outside the editor, which
	# print harmless EditorInterface script errors; judge it by exit code.
	local pattern="^  FAIL \|SCRIPT ERROR\|Parse Error"
	[ "$name" = "editor_tools_roundtrip_test" ] && pattern="^  FAIL \|Parse Error"
	# Tests that don't load game_root trip a known GameManager boot error
	# (load_map_scene assigns the menu Control to a Node2D); ignore just that.
	local hits
	hits=$(awk '/SCRIPT ERROR/{e=$0; getline n; if (n ~ /load_map_scene/) next; print e; next} {print}' "$log" | grep -c "$pattern")
	if [ $code -eq 0 ] && [ "$hits" -eq 0 ]; then
		pass=$((pass+1)); echo "PASS  $name"
	else
		fail=$((fail+1)); failed+=("$name"); echo "FAIL  $name (exit $code)"
		grep -E "^  FAIL |SCRIPT ERROR|Parse Error|ERROR:" "$log" | head -8 | sed 's/^/        /'
	fi
}
match() { [ $# -eq 0 ] && return 0; for w in "${FILTERS[@]}"; do [[ "$1" == *"$w"* ]] && return 0; done; return 1; }
FILTERS=("$@")
for scene in tests/*_test.tscn; do
	name="$(basename "$scene" .tscn)"
	[ ${#FILTERS[@]} -gt 0 ] && ! match "$name" && continue
	run_one "$name" "res://$scene"
done
if [ ${#FILTERS[@]} -eq 0 ] || match "editor_tools_roundtrip_test"; then
	run_one "editor_tools_roundtrip_test" -s "res://tests/editor_tools_roundtrip_test.gd"
fi

[ -f "$BACKUP/save.tres" ] && cp "$BACKUP/save.tres" "$SAVE_DIR/save.tres"
git checkout -- "addons/godot-git-plugin/windows/~libgit_plugin.windows.editor.x86_64.dll" 2>/dev/null
echo "----"
echo "$pass passed, $fail failed"
[ $fail -gt 0 ] && echo "Failed: ${failed[*]}" && echo "Logs: $BACKUP" && exit 1
exit 0
