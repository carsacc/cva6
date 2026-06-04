# CVA6 cv64a6 — GF22FDX area synthesis (Genus)

Estimate the **silicon area of the CVA6 core logic** in GlobalFoundries 22FDX,
for the CHAOS RISC-V SoC feasibility study. Runs Cadence **Genus** on `mazo`.

## What it measures (and what it doesn't)
- Synthesizes `cva6` (config **cv64a6_imafdc_sv39**) against the GF22FDX HD
  standard-cell library.
- **Cache SRAMs are black-boxed** — we have no GF22 SRAM IP, and for a
  feasibility area number you don't need it. The result is the **core LOGIC**
  area (control + datapath), comparable to the *"210 kGE core (without
  caches)"* of the Ariane GF22FDX tape-out (arXiv:1904.05442).
- The **cache SRAM area is estimated separately** from the foundry SRAM
  datasheet (16 KB I$ + 32 KB D$ + tags) — it is NOT in this number.

## Files
- `cva6.flist`   — ordered RTL list for cv64a6 (from `pd/synth` `pre_cva6_synth`).
- `cva6.incdirs` — include dirs.
- `cva6_genus.tcl` — the Genus flow (read libs/RTL, blackbox SRAM, elaborate,
  clock, `syn_generic`/`syn_map`, `report_gates`/`report_area`).
- `run_genus.sh` — wrapper (sets repo root, GF22 lib, period).

## Run (on mazo)
```sh
cd <repo>/pd/synth/genus
./run_genus.sh
# tunables:
PERIOD_NS=2.0 ./run_genus.sh        # 500 MHz target (vs default 10 ns = min-area floor)
GF22_LIB=<other corner .lib.gz> ./run_genus.sh
```
Library used by default (typical corner, for area):
`.../gf22nhsda/20hd/hdl/lvt/6.01a/liberty/logic_synth_lvf/gf22nsdllogl20hdl116a_TT_0P80V_0P00V_0P00V_0P00V_25C.lib.gz`

## Output
- `reports/cva6_gates.rpt` — gate count incl. **NAND2-equivalent gates (≈ kGE)**.
- `reports/cva6_area.rpt` / `cva6_area_hier.rpt` — cell area in µm².
- Sanity check: core logic should land near the paper's ~200–250 kGE for cv64a6.

## Notes / iteration
- First run may need small fixes (exact Genus attribute names for blackboxing,
  any unresolved module, the config define). Adjust `cva6_genus.tcl` and re-run.
- `tc_sram` (behavioral cache RAM) is intentionally excluded from the read list
  so it stays a black box; `hpdcache` already uses blackbox macro stubs.
- The default 10 ns period gives the minimum-area floor; tighten to see the
  area/speed tradeoff.
