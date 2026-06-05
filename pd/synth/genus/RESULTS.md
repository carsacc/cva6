# CVA6 cv64a6 — GF22FDX area synthesis results

Cadence Genus 22.13 on `mazo`, run 2026-06-04.

## Configuration
- Top module: `cva6`, config **cv64a6_imafdc_sv39** (RV64GC, double-precision FPU).
- Includes the project's **AES accelerator** (`ex_stage/aes_gen.aes_i`).
- Library: **GF22FDX HD LVT 6.01a**, corner **TT 0.80 V 25 °C**
  (`gf22nsdllogl20hdl116a_TT_0P80V_0P00V_0P00V_0P00V_25C`).
- Target period: **10 ns** (relaxed = minimum-area floor; timing met with wide slack).
- **Cache SRAMs black-boxed** (no GF22 SRAM IP) → this is **core LOGIC area only**.

## Headline numbers (min-area floor, 100 MHz / 10 ns)
| Metric | Value |
|---|---|
| Cell area (logic) | **90 386 µm² ≈ 0.090 mm²** |
| Instances | 133 115 |
| NAND2 reference (`HDBLVT20_ND2_1`) | 0.2506 µm² / GE |
| **Gate-equivalent** | **≈ 361 kGE** |

## Frequency / area trade-off and Fmax
Same core, TT 0.80 V 25 °C, SRAM blackboxed. The clock period was swept:

| Target | Period | Cell area | Cells | kGE | WNS (slack) |
|---|---|---:|---:|---:|---|
| 100 MHz | 10 ns | 90 386 µm² | 133 115 | 361 | huge (+) |
| **800 MHz** | 1.25 ns | **95 831 µm²** | 155 368 | **382** | **+11 ps (MET, barely)** |
| 1 GHz | 1.0 ns | — | — | — | **NOT met (−153 ps), unstable** |

- **Fmax ≈ 800 MHz** at the TT (typical) corner — closes with only +11 ps margin.
  1 GHz is not achievable in GF22FDX HD LVT (and Genus thrashes/dies on that
  over-constraint). Area grows only ~6 % from the 100 MHz floor to 800 MHz, but
  cell count jumps 133k→155k (faster cells + buffering to meet timing).
- **Critical path: the FPU** — `ex_stage/.../i_fpnew_cast_multi` (FP format
  conversion). That's the frequency bottleneck.
- TT is optimistic; sign-off at the slow corner (SSG) would lower Fmax further
  (likely ~600-650 MHz).
- A mapped database is saved at `pd/synth/genus/cva6_mapped.db` (reopen with
  `read_db cva6_mapped.db`). Timing report: `reports/cva6_timing.rpt`.

## Breakdown by block
| Block | µm² | kGE |
|---|---:|---:|
| `ex_stage` (ALU + FPU + mult + LSU + AES) | 45 267 | 181 |
| ↳ FPU F/D (cvfpu + C910 divsqrt) | ~19 200 | ~77 |
| ↳ LSU + MMU + PMP | 15 548 | 62 |
| ↳ mult / div | 8 142 | 32 |
| ↳ AES accelerator (project) | 2 344 | 9.4 |
| WT cache subsystem (control; SRAM blackboxed) | 8 884 | 35 |
| Frontend / BHT-BTB | 1 031 | 4 |
| id / issue / csr / regfile / commit / controller | ~rest | ~140 |

## Reading vs. the literature
The ~210 kGE figure often cited for Ariane in GF22FDX (arXiv:1904.05442) is a
leaner configuration (no full F/D FPU, no AES accelerator). The 361 kGE here is
dominated by the **double-precision FPU (~77 kGE)** plus MMU/PMP and the
project's **AES block (~9 kGE)**. Excluding AES, a vanilla cv64a6 with this
config lands at ~351 kGE.

## Caveats / next steps
- **Logic only** — no SRAM, no routing. At a realistic ~65-70 % placement
  density the placed core logic is ≈ **0.13 mm²**.
- **Add cache-SRAM area separately** (16 KB I$ + 32 KB D$ + tags) from the GF22
  SRAM datasheet for a full-core estimate.
- 10 ns is the area floor; tighten `PERIOD_NS` for the real ASIC frequency
  (area will grow with the timing constraint).
