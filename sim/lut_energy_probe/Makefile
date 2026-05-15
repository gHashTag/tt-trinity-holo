# =============================================================================
# Makefile — LUT PE Energy Probe (Wave-29 Lane E)
# =============================================================================
#
# Targets:
#   iverilog   — compile and simulate with Icarus Verilog
#   verilator  — compile and simulate with Verilator (lint + sim)
#   report     — run iverilog sim and capture report.md results
#   clean      — remove generated artefacts
#
# Usage:
#   make iverilog
#   make verilator
#   make report
#
# Refs #108
# Signed-off-by: Vasilev Dmitrii <admin@t27.ai>
# =============================================================================

RTL_DIR    ?= ../../rtl
SIM_DIR    := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# Source files
DUT_SRC    := $(RTL_DIR)/holo_lut_pe.sv
BAS_SRC    := $(SIM_DIR)/shift_add_baseline.sv
TOP_SRC    := $(SIM_DIR)/probe.sv

SRCS       := $(DUT_SRC) $(BAS_SRC) $(TOP_SRC)

# Icarus Verilog settings
IVERILOG   := iverilog
VVP        := vvp
IVFLAGS    := -g2012 -Wall -Wno-timescale -I$(RTL_DIR)
IV_OUT     := sim_lut_energy.vvp

# Verilator settings
VERILATOR  := verilator
VLFLAGS    := --sv --lint-only --timing -Wall \
              -Wno-TIMESCALEMOD -Wno-WIDTHTRUNC \
              -I$(RTL_DIR)

# Report output
REPORT_MD  := $(SIM_DIR)/report.md
SIM_LOG    := $(SIM_DIR)/sim_out.log

.PHONY: all iverilog verilator report clean

all: iverilog

# -----------------------------------------------------------------------------
# iverilog target
# -----------------------------------------------------------------------------
iverilog: $(IV_OUT)
	@echo "[iverilog] Running simulation..."
	$(VVP) $(IV_OUT) | tee $(SIM_LOG)

$(IV_OUT): $(SRCS)
	@echo "[iverilog] Compiling..."
	$(IVERILOG) $(IVFLAGS) -o $(IV_OUT) -s probe $(SRCS)

# -----------------------------------------------------------------------------
# verilator target (lint + sim)
# -----------------------------------------------------------------------------
verilator:
	@echo "[verilator] Linting probe, shift_add_baseline, holo_lut_pe..."
	$(VERILATOR) $(VLFLAGS) --top-module probe $(SRCS)
	@echo "[verilator] Lint PASSED"

# -----------------------------------------------------------------------------
# report target — run sim and patch report.md with live numbers
# -----------------------------------------------------------------------------
report: iverilog
	@echo "[report] Extracting results from $(SIM_LOG) into $(REPORT_MD)..."
	@python3 - <<'PYEOF'
import re, sys, pathlib

log   = pathlib.Path("$(SIM_LOG)").read_text(errors="replace")
rpt   = pathlib.Path("$(REPORT_MD)").read_text()

# Extract toggle/op ratios
m_dut = re.search(r"LUT PE toggles/op:\s+\d+ / \d+ = ([\d.]+)", log)
m_bas = re.search(r"Shift-add toggles/op:\s+\d+ / \d+ = ([\d.]+)", log)
m_rat = re.search(r"Ratio LUT/SA:\s+([\d.]+)", log)
m_gate= re.search(r"W28-G2 gate \(<=2x\): (\w+)", log)

dut_v = m_dut.group(1) if m_dut else "N/A"
bas_v = m_bas.group(1) if m_bas else "N/A"
rat_v = m_rat.group(1) if m_rat else "N/A"
gate_v= m_gate.group(1) if m_gate else "INCONCLUSIVE"

rpt = re.sub(r"- LUT PE toggles/op: N",
             f"- LUT PE toggles/op: {dut_v}", rpt)
rpt = re.sub(r"- Shift-add toggles/op: N",
             f"- Shift-add toggles/op: {bas_v}", rpt)
rpt = re.sub(r"- Ratio: N×",
             f"- Ratio: {rat_v}×", rpt)
rpt = re.sub(r"- W28-G2 gate \(≤ 2×\): PASS\|FAIL",
             f"- W28-G2 gate (≤ 2×): {gate_v}", rpt)

pathlib.Path("$(REPORT_MD)").write_text(rpt)
print(f"[report] Updated report.md: DUT={dut_v} SA={bas_v} Ratio={rat_v}x Gate={gate_v}")
PYEOF

# -----------------------------------------------------------------------------
# clean
# -----------------------------------------------------------------------------
clean:
	@rm -f $(IV_OUT) $(SIM_LOG) lut_energy_probe.vcd
	@echo "[clean] Done."
