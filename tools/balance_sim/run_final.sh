#!/usr/bin/env bash
# The full-size final run: neutral test class, all six levels, all four
# profiles, Strength and Intellect (400 characters per level x profile x
# build, 2 fights per tier each, one dungeon run each, outlevelling on the
# on-curve shards), plus a cheap Mage check (on-curve, 150 characters).
# Then both reports. Run from the project root:
#
#   GODOT=/path/to/Godot_v4.5.1 MAXP=12 tools/balance_sim/run_final.sh <out_dir>
#
# MAXP = Godot processes at a time (each ~0.6-0.8 GB). Use an empty <out_dir>.
GODOT="${GODOT:-godot}"; OUT="$1"; MAXP="${MAXP:-12}"
N="$OUT/neutral"; M="$OUT/mage"; mkdir -p "$N" "$M"
for L in 1 18 35 50 75 100; do
  while [ $(jobs -rp | wc -l) -ge $MAXP ]; do sleep 5; done
  "$GODOT" --headless --path . res://tools/balance_sim/balance_sim.tscn -- mode=run levels=$L profiles=on_curve class=mage \
    tag=mfinal out="$M/L$L.csv" chars=150 fights=2 runs=1 seed=1 > "$M/L$L.log" 2>&1 &
  for P in on_curve undergeared well_geared min_maxed; do
    while [ $(jobs -rp | wc -l) -ge $MAXP ]; do sleep 5; done
    OL=""; if [ $P = on_curve ] && [ $L != 100 ]; then OL="outlevel=1 outlevel_levels=$L"; fi
    "$GODOT" --headless --path . res://tools/balance_sim/balance_sim.tscn -- mode=run levels=$L profiles=$P \
      tag=nfinal out="$N/L${L}_$P.csv" $OL chars=400 fights=2 runs=1 seed=1 > "$N/L${L}_$P.log" 2>&1 &
  done
done
wait
"$GODOT" --headless --path . res://tools/balance_sim/balance_sim.tscn -- mode=report in="$N" tag=nfinal \
  title="Balance Sim 2026-09-27 final" md="$OUT/final.md" csv="$OUT/final.csv" > "$OUT/report_n.log" 2>&1
"$GODOT" --headless --path . res://tools/balance_sim/balance_sim.tscn -- mode=report in="$M" tag=mfinal \
  title="Balance Sim 2026-09-27 final (Mage)" md="$OUT/final_mage.md" csv="$OUT/final_mage.csv" > "$OUT/report_m.log" 2>&1
echo "reports: $OUT/final.md, $OUT/final_mage.md"
