# CVA6 (cv64a6_imafdc_sv39) core-logic synthesis in GF22FDX with Cadence Genus.
# Purpose: AREA ESTIMATE for the CHAOS feasibility study.
#
# Cache SRAMs are treated as BLACK BOXES (we have no GF22 SRAM IP). That yields
# the area of the CORE LOGIC only (control + datapath), directly comparable to
# the "210 kGE core (without caches)" reported for Ariane in GF22FDX
# (arXiv:1904.05442). The cache SRAM area is estimated separately from the
# foundry SRAM datasheets; it is NOT part of this number.
#
# Env (set by run_genus.sh):
#   CVA6_REPO_DIR  - cva6 repo root on mazo
#   GF22_LIB       - path to the GF22FDX HD .lib(.gz) corner (TT for area)
#   PERIOD_NS      - target clock period (relaxed by default = min-area floor)

set REPO        $env(CVA6_REPO_DIR)
set GF22_LIB    $env(GF22_LIB)
set PERIOD_NS   [expr {[info exists env(PERIOD_NS)] ? $env(PERIOD_NS) : 10.0}]
set TARGET_CFG  cv64a6_imafdc_sv39
set HPDCACHE_DIR ${REPO}/core/cache_subsystem/hpdcache
set SDIR        [file dirname [file normalize [info script]]]

# ---- technology library -----------------------------------------------------
read_libs $GF22_LIB

# ---- include dirs ------------------------------------------------------------
set incs {}
foreach line [split [read [open ${SDIR}/cva6.incdirs]] "\n"] {
    set line [string trim $line]
    if {$line eq ""} continue
    lappend incs [string map [list {${CVA6_REPO_DIR}} $REPO] $line]
}
set_db init_hdl_search_path $incs

# ---- RTL file list (ordered) -------------------------------------------------
# Skip the behavioral tc_sram: leaving it unresolved makes the cache data/tag
# RAMs blackboxes (we want logic-only area). hpdcache macros are already
# blackbox stubs in the flist.
set files {}
foreach line [split [read [open ${SDIR}/cva6.flist]] "\n"] {
    set line [string trim $line]
    if {$line eq "" || [string match "//*" $line]} continue
    if {[string match "*tech_cells_generic*tc_sram.sv" $line]} continue
    set line [string map [list \
        {${CVA6_REPO_DIR}} $REPO \
        {${HPDCACHE_DIR}}  $HPDCACHE_DIR \
        {${TARGET_CFG}}    $TARGET_CFG] $line]
    lappend files $line
}

set_db hdl_error_on_blackbox false
read_hdl -sv -define { HPDCACHE_ASSERT_OFF } $files

# ---- elaborate ---------------------------------------------------------------
elaborate cva6

# Belt-and-suspenders: force any SRAM leaf modules that still resolved to be
# black boxes so they are not counted as flip-flop arrays.
foreach m {tc_sram hpdcache_sram_1rw hpdcache_sram_wbyteenable_1rw hpdcache_sram_wmask_1rw} {
    set d [get_db modules -if ".name == $m"]
    if {[llength $d]} { set_db $d .blackbox true }
}

# ---- constraints (area-oriented) --------------------------------------------
create_clock -name clk -period $PERIOD_NS [get_ports clk_i]
set_db syn_generic_effort medium
set_db syn_map_effort      medium

# Run as ONE process, fully serial: no forked super-thread CPU-server processes.
# Genus implements multi-CPU by launching ST server processes ([ST-120]); those
# helpers die when the launching SSH session is reaped, silently killing the
# master mid syn_generic (observed 3x at tight constraints). max_cpus_per_server 1
# = no ST servers at all → robust for a detached run. Slower but reliable.
set_db auto_super_thread false
set_db max_cpus_per_server 1

# ---- synthesize --------------------------------------------------------------
syn_generic
syn_map

# ---- reports -----------------------------------------------------------------
file mkdir ${SDIR}/reports
report_gates            > ${SDIR}/reports/cva6_gates.rpt
report_area             > ${SDIR}/reports/cva6_area.rpt
report_area -depth 2    > ${SDIR}/reports/cva6_area_hier.rpt
report_timing -nworst 5 > ${SDIR}/reports/cva6_timing.rpt
report_messages         > ${SDIR}/reports/cva6_messages.rpt

puts "==================== CVA6 cv64a6 GF22FDX AREA (logic, SRAM blackboxed) ===================="
report_gates
puts "------------------------------------------------------------------------------------------"
report_area
puts "=========================================================================================="
