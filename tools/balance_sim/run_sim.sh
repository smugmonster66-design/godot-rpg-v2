#!/usr/bin/env bash
# Runs the balance simulator in parallel shards (one Godot process per level),
# then builds the report.
#
#   GODOT=/path/to/Godot_v4.5.1 tools/balance_sim/run_sim.sh <out_dir> <tag> <title> <report.md> <summary.csv> [extra args...]
#
# Extra args go to every shard (e.g. chars=200 fights=2 runs=1 knob.DEFENSE_K=4).
# The report reads every CSV in <out_dir>: use a new, empty <out_dir> for each
# run. To add characters to a run, use the same <out_dir> with SUFFIX=_b2 and
# char_offset=N (N = the characters already run). Run from the project root. Tests and the sim write nothing to the save.
set -e
GODOT="${GODOT:-godot}"
OUT="$1"; TAG="$2"; TITLE="$3"; MD="$4"; CSV="$5"; shift 5
mkdir -p "$OUT"
pids=()
for L in 1 18 35 50 75 100; do
  OL=""
  case $L in 1|18|35|50|75) OL="outlevel=1 outlevel_levels=$L";; esac
  "$GODOT" --headless --path . res://tools/balance_sim/balance_sim.tscn -- mode=run levels=$L tag="$TAG" \
    out="$OUT/L$L${SUFFIX}.csv" $OL "$@" > "$OUT/L$L${SUFFIX}.log" 2>&1 &
  pids+=($!)
done
for p in "${pids[@]}"; do wait "$p"; done
"$GODOT" --headless --path . res://tools/balance_sim/balance_sim.tscn -- mode=report in="$OUT" tag="$TAG" \
  title="$TITLE" md="$MD" csv="$CSV" ${INTRO:+intro="$INTRO"} > "$OUT/report.log" 2>&1
echo "report: $MD"
