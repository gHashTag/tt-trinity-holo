# =============================================================================
# Makefile — 400 MHz Timing Probe (Wave-30 Lane T)
# =============================================================================
#
# Targets:
#   yosys    — synthesise all four RTL surfaces with Yosys (generic Liberty)
#   report   — run yosys synth + OpenSTA timing analysis, write results to report.md
#   clean    — remove generated artefacts
#
# Tool chain (open-source, sim-grade):
#   Yosys  >= 0.38  (synthesis)
#   OpenSTA >= 2.6  (static timing analysis against generic Liberty)
#
# IMPORTANT — SYNTH-SIM LIMITATION (R5-HONEST):
#   This Makefile uses Yosys + OpenSTA with the generic sky130 Liberty as a
#   proxy for TTIHP27a timing.  Delays are ESTIMATES ONLY.  Commercial-STA
#   sign-off (PrimeTime / Tempus) with the real TTIHP27a PDK Liberty is
#   required before tape-out.  The 🟡 SYNTH-SIM verdict in report.md reflects
#   this limitation and must NOT be promoted to 🟢 SILICON without measured data.
#
# Usage:
#   make yosys         # synthesise all surfaces
#   make report        # synthesise + STA + patch report.md
#   make clean         # remove build artefacts
#
# Refs #109
# Signed-off-by: Vasilev Dmitrii <admin@t27.ai>
# =============================================================================

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
RTL_DIR    ?= ../../rtl
SIM_DIR    := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR  := $(SIM_DIR)/build

# ---------------------------------------------------------------------------
# RTL surfaces (R18: these files are FROZEN — not modified by Lane T)
# ---------------------------------------------------------------------------
SRC_LANE_V       := $(RTL_DIR)/holo_lut_pe.sv
SRC_LANE_W       := $(RTL_DIR)/holo_bitrom_bank.sv
SRC_LANE_V_PRIME := $(RTL_DIR)/holo_2x2_mesh.sv
SRC_LANE_S       := $(RTL_DIR)/holo_sparsity_24.sv

# ---------------------------------------------------------------------------
# Yosys settings
# ---------------------------------------------------------------------------
YOSYS        := yosys
# Generic Liberty fallback (sky130 HD). Override to point at TTIHP27a Liberty:
#   make LIBERTY=/path/to/ttihp27a.lib yosys
LIBERTY      ?= $(shell yosys-config --datdir)/techlibs/sky130/sky130hd.lib
YOSYS_FLAGS  :=
SDC_FILE     := $(SIM_DIR)/constraints.sdc

# ---------------------------------------------------------------------------
# OpenSTA settings
# ---------------------------------------------------------------------------
STA          := sta
STA_FLAGS    :=

# ---------------------------------------------------------------------------
# Per-surface Yosys synthesis script template
# ---------------------------------------------------------------------------
define YOSYS_SCRIPT
read_verilog -sv $(1)
synth -top $(2) -flatten
dfflibmap -liberty $(LIBERTY)
abc -liberty $(LIBERTY) -D 2500   # 2500 ps = 400 MHz
write_verilog -noattr $(BUILD_DIR)/$(2)_netlist.v
stat -liberty $(LIBERTY) > $(BUILD_DIR)/$(2)_stat.log
endef

# ---------------------------------------------------------------------------
# Per-surface OpenSTA script template
# ---------------------------------------------------------------------------
define STA_SCRIPT
read_liberty $(LIBERTY)
read_verilog $(BUILD_DIR)/$(2)_netlist.v
link_design $(2)
read_sdc $(SDC_FILE)
report_checks -path_delay max -fields {slew cap input_pin} > $(BUILD_DIR)/$(2)_setup.rpt
report_checks -path_delay min -fields {slew cap input_pin} > $(BUILD_DIR)/$(2)_hold.rpt
report_wns  > $(BUILD_DIR)/$(2)_wns.log
report_tns  > $(BUILD_DIR)/$(2)_tns.log
endef

# ---------------------------------------------------------------------------
# Phony targets
# ---------------------------------------------------------------------------
.PHONY: all yosys report clean

all: yosys

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

# ---------------------------------------------------------------------------
# yosys — synthesise all four surfaces
# ---------------------------------------------------------------------------
yosys: $(BUILD_DIR)
	@echo "[yosys] Synthesising Lane V  (holo_lut_pe)..."
	@echo "$(call YOSYS_SCRIPT,$(SRC_LANE_V),holo_lut_pe)" \
	      > $(BUILD_DIR)/synth_lane_v.ys
	$(YOSYS) $(YOSYS_FLAGS) $(BUILD_DIR)/synth_lane_v.ys \
	      2>&1 | tee $(BUILD_DIR)/synth_lane_v.log

	@echo "[yosys] Synthesising Lane W  (holo_bitrom_bank)..."
	@echo "$(call YOSYS_SCRIPT,$(SRC_LANE_W),holo_bitrom_bank)" \
	      > $(BUILD_DIR)/synth_lane_w.ys
	$(YOSYS) $(YOSYS_FLAGS) $(BUILD_DIR)/synth_lane_w.ys \
	      2>&1 | tee $(BUILD_DIR)/synth_lane_w.log

	@echo "[yosys] Synthesising Lane V' (holo_2x2_mesh)..."
	@echo "$(call YOSYS_SCRIPT,$(SRC_LANE_V_PRIME),holo_2x2_mesh)" \
	      > $(BUILD_DIR)/synth_lane_vp.ys
	$(YOSYS) $(YOSYS_FLAGS) $(BUILD_DIR)/synth_lane_vp.ys \
	      2>&1 | tee $(BUILD_DIR)/synth_lane_vp.log

	@echo "[yosys] Synthesising Lane S  (holo_sparsity_24)..."
	@echo "$(call YOSYS_SCRIPT,$(SRC_LANE_S),holo_sparsity_24)" \
	      > $(BUILD_DIR)/synth_lane_s.ys
	$(YOSYS) $(YOSYS_FLAGS) $(BUILD_DIR)/synth_lane_s.ys \
	      2>&1 | tee $(BUILD_DIR)/synth_lane_s.log

	@echo "[yosys] Synthesis complete. Netlists in $(BUILD_DIR)/"

# ---------------------------------------------------------------------------
# report — run STA on all synthesised netlists and patch report.md
# ---------------------------------------------------------------------------
report: yosys
	@echo "[sta] Running OpenSTA for all surfaces..."

	@printf "read_liberty $(LIBERTY)\nread_verilog $(BUILD_DIR)/holo_lut_pe_netlist.v\nlink_design holo_lut_pe\nread_sdc $(SDC_FILE)\nreport_wns > $(BUILD_DIR)/holo_lut_pe_wns.log\nreport_tns >> $(BUILD_DIR)/holo_lut_pe_wns.log\nreport_checks -path_delay max > $(BUILD_DIR)/holo_lut_pe_setup.rpt\nreport_checks -path_delay min > $(BUILD_DIR)/holo_lut_pe_hold.rpt\n" \
	      > $(BUILD_DIR)/sta_lane_v.tcl
	$(STA) $(STA_FLAGS) $(BUILD_DIR)/sta_lane_v.tcl 2>&1 | tee $(BUILD_DIR)/sta_lane_v.log

	@printf "read_liberty $(LIBERTY)\nread_verilog $(BUILD_DIR)/holo_bitrom_bank_netlist.v\nlink_design holo_bitrom_bank\nread_sdc $(SDC_FILE)\nreport_wns > $(BUILD_DIR)/holo_bitrom_bank_wns.log\nreport_tns >> $(BUILD_DIR)/holo_bitrom_bank_wns.log\nreport_checks -path_delay max > $(BUILD_DIR)/holo_bitrom_bank_setup.rpt\nreport_checks -path_delay min > $(BUILD_DIR)/holo_bitrom_bank_hold.rpt\n" \
	      > $(BUILD_DIR)/sta_lane_w.tcl
	$(STA) $(STA_FLAGS) $(BUILD_DIR)/sta_lane_w.tcl 2>&1 | tee $(BUILD_DIR)/sta_lane_w.log

	@printf "read_liberty $(LIBERTY)\nread_verilog $(BUILD_DIR)/holo_2x2_mesh_netlist.v\nlink_design holo_2x2_mesh\nread_sdc $(SDC_FILE)\nreport_wns > $(BUILD_DIR)/holo_2x2_mesh_wns.log\nreport_tns >> $(BUILD_DIR)/holo_2x2_mesh_wns.log\nreport_checks -path_delay max > $(BUILD_DIR)/holo_2x2_mesh_setup.rpt\nreport_checks -path_delay min > $(BUILD_DIR)/holo_2x2_mesh_hold.rpt\n" \
	      > $(BUILD_DIR)/sta_lane_vp.tcl
	$(STA) $(STA_FLAGS) $(BUILD_DIR)/sta_lane_vp.tcl 2>&1 | tee $(BUILD_DIR)/sta_lane_vp.log

	@printf "read_liberty $(LIBERTY)\nread_verilog $(BUILD_DIR)/holo_sparsity_24_netlist.v\nlink_design holo_sparsity_24\nread_sdc $(SDC_FILE)\nreport_wns > $(BUILD_DIR)/holo_sparsity_24_wns.log\nreport_tns >> $(BUILD_DIR)/holo_sparsity_24_wns.log\nreport_checks -path_delay max > $(BUILD_DIR)/holo_sparsity_24_setup.rpt\nreport_checks -path_delay min > $(BUILD_DIR)/holo_sparsity_24_hold.rpt\n" \
	      > $(BUILD_DIR)/sta_lane_s.tcl
	$(STA) $(STA_FLAGS) $(BUILD_DIR)/sta_lane_s.tcl 2>&1 | tee $(BUILD_DIR)/sta_lane_s.log

	@echo "[report] Patching report.md with STA results..."
	@python3 - <<'PYEOF'
import re, pathlib, subprocess

BUILD = pathlib.Path("$(BUILD_DIR)")
REPORT = pathlib.Path("$(SIM_DIR)/report.md")

def extract_wns(log_path):
    """Extract WNS (worst negative slack) in ps from OpenSTA output."""
    try:
        txt = pathlib.Path(log_path).read_text(errors="replace")
        # OpenSTA reports WNS as: "wns X.XX" (in ns)
        m = re.search(r"^wns\s+([-\d.]+)", txt, re.MULTILINE)
        if m:
            return int(float(m.group(1)) * 1000)  # ns -> ps
    except FileNotFoundError:
        pass
    return None

def extract_hold_slack(log_path):
    """Extract best hold slack (min path) in ps."""
    try:
        txt = pathlib.Path(log_path).read_text(errors="replace")
        # OpenSTA min path slack: look for "slack (MET)" or "slack (VIOLATED)"
        m = re.search(r"slack\s*\((?:MET|VIOLATED)\)\s+([-\d.]+)", txt)
        if m:
            return int(float(m.group(1)) * 1000)
    except FileNotFoundError:
        pass
    return None

surfaces = [
    ("holo_lut_pe",     "Lane V  — LUT PE",     "holo_lut_pe"),
    ("holo_bitrom_bank","Lane W  — BitROM bank", "holo_bitrom_bank"),
    ("holo_2x2_mesh",   "Lane V' — 2×2 mesh",   "holo_2x2_mesh"),
    ("holo_sparsity_24","Lane S  — Sparsity 24", "holo_sparsity_24"),
]

rows = []
for mod, label, name in surfaces:
    setup_wns = extract_wns(BUILD / f"{mod}_wns.log")
    hold_slack = extract_hold_slack(BUILD / f"{mod}_hold.rpt")
    s_str = f"{setup_wns:+d}" if setup_wns is not None else "N/A (run make report)"
    h_str = f"{hold_slack:+d}" if hold_slack is not None else "N/A (run make report)"
    verdict = "PASS" if (setup_wns is not None and setup_wns >= 0 and hold_slack is not None and hold_slack >= 0) \
         else ("FAIL" if (setup_wns is not None and setup_wns < 0) else "PENDING")
    rows.append(f"| {label} | `{mod}` | {s_str} | {h_str} | {verdict} |")

table_body = "\n".join(rows)
rpt = REPORT.read_text()
rpt = re.sub(
    r"(\| Lane \| Module \| setup_slack_ps \| hold_slack_ps \| verdict \|\n\|[-| ]+\|\n)([^\n#]*\n)*",
    r"\1" + table_body + "\n",
    rpt,
)
REPORT.write_text(rpt)
print("[report] report.md updated.")
PYEOF
	@echo "[report] Done. See report.md for results."

# ---------------------------------------------------------------------------
# clean
# ---------------------------------------------------------------------------
clean:
	@rm -rf $(BUILD_DIR)
	@echo "[clean] Done."
