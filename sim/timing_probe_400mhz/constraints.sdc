# =============================================================================
# constraints.sdc — 400 MHz Timing Probe (Wave-30 Lane T)
# =============================================================================
#
# Target: TTIHP27a-like process, 400 MHz (2.5 ns clock period)
# Surfaces: Lane V LUT PE, Lane W BitROM bank, Lane V' 2x2 mesh, Lane S sparsity 24
#
# NOTE: These are synthesis-grade constraints for Yosys + OpenSTA (sim-grade proxy).
# Commercial STA (Synopsys PrimeTime / Cadence Tempus) with a real TTIHP27a Liberty
# file is required for tape-out sign-off. See report.md for the full disclosure.
#
# Refs #109
# Signed-off-by: Vasilev Dmitrii <admin@t27.ai>
# =============================================================================

# -----------------------------------------------------------------------------
# Clock definition — 400 MHz = 2.5 ns period
# -----------------------------------------------------------------------------
create_clock -name clk -period 2.5 [get_ports clk]

# -----------------------------------------------------------------------------
# I/O timing budgets — 0.5 ns on each side (leaves 1.5 ns for internal logic)
# -----------------------------------------------------------------------------
set_input_delay  -clock clk 0.5 [all_inputs]
set_output_delay -clock clk 0.5 [all_outputs]

# -----------------------------------------------------------------------------
# Fanout / load constraints
# -----------------------------------------------------------------------------
set_max_fanout 10 [current_design]
set_load 0.001 [all_outputs]

# -----------------------------------------------------------------------------
# Drive strength (generic — no Liberty cell available for Yosys synth-sim)
# -----------------------------------------------------------------------------
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_2 [all_inputs]

# -----------------------------------------------------------------------------
# False paths for async reset / constant tie-offs (if present)
# -----------------------------------------------------------------------------
# set_false_path -from [get_ports rst_n]   # uncomment when rst_n is used

# -----------------------------------------------------------------------------
# Multicycle paths — none declared at this probe stage
# -----------------------------------------------------------------------------

# EOF
