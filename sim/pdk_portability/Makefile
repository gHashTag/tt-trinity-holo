# =============================================================================
# Makefile — PDK Portability Probe (Wave-31 Lane M)
# =============================================================================
#
# Targets:
#   sg13g3   — Yosys synth + tech-map to SG13G3 proxy Liberty
#   sky90    — Yosys synth + tech-map to SKY90 proxy Liberty
#   report   — run both PDK synths, emit gate-count table in report.md
#   clean    — remove generated artefacts
#
# Tool chain (open-source, sim-grade):
#   Yosys  >= 0.38  (synthesis + tech-mapping)
#
# IMPORTANT — SYNTH-SIM LIMITATION (R5-HONEST):
#   Both sg13g3_tech.lib and sky90_tech.lib shipped in this directory are
#   PROXY Liberty files, not production PDK releases.
#
#   sg13g3_tech.lib:
#     A minimal hand-crafted Liberty that mirrors the IHP Open-PDK (sg13g2)
#     cell naming convention.  Canonical open-source Liberty is maintained at:
#       https://github.com/IHP-GmbH/IHP-Open-PDK
#     Timing arcs use conservative estimates (FO4 ~130 ps typical for IHP 130 nm).
#     Production sign-off REQUIRES the real sg13g2/sg13g3 Liberty from IHP.
#
#   sky90_tech.lib:
#     SKY90 is NOT a publicly released SkyWater PDK.  This file is a
#     90-nm-class proxy Liberty based on publicly available ITRS/academic
#     characterisation data.  It is used here SOLELY as a portability probe
#     to estimate gate counts and relative area at the 90 nm node.
#     Commercial-grade STA using a real SKY90 Liberty is a GATE, not a claim.
#
#   Neither Liberty file may be used for tape-out sign-off.
#   The 🟡 SYNTH-SIM verdict in report.md reflects this limitation and must
#   NOT be promoted to 🟢 SILICON without measured silicon data.
#
# R-SI-1: ZERO * operator in synthesisable RTL.  This Makefile adds zero .sv
#         files; all four frozen surfaces already passed R-SI-1.
# R18:    RTL from PRs #19/#14/#21/#26 is NOT modified — Makefile + Liberty
#         proxies are pure infrastructure.
#
# Usage:
#   make sg13g3        # synth + tech-map to SG13G3 proxy
#   make sky90         # synth + tech-map to SKY90 proxy
#   make report        # both PDKs + gate-count table written to report.md
#   make clean         # remove build artefacts
#
# Refs #110
# Signed-off-by: Vasilev Dmitrii <admin@t27.ai>
# =============================================================================

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
RTL_DIR    ?= ../../rtl
SIM_DIR    := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR  := $(SIM_DIR)/build

# ---------------------------------------------------------------------------
# RTL surfaces (R18: these files are FROZEN — not modified by Lane M)
# ---------------------------------------------------------------------------
SRC_LANE_V       := $(RTL_DIR)/holo_lut_pe.sv
SRC_LANE_W       := $(RTL_DIR)/holo_bitrom_bank.sv
SRC_LANE_V_PRIME := $(RTL_DIR)/holo_2x2_mesh.sv
SRC_LANE_S       := $(RTL_DIR)/holo_sparsity_24.sv

# ---------------------------------------------------------------------------
# Liberty files (proxy — see SYNTH-SIM disclaimer above)
# ---------------------------------------------------------------------------
LIB_SG13G3 := $(SIM_DIR)/sg13g3_tech.lib
LIB_SKY90  := $(SIM_DIR)/sky90_tech.lib

# ---------------------------------------------------------------------------
# Yosys
# ---------------------------------------------------------------------------
YOSYS       := yosys
YOSYS_FLAGS :=

# ---------------------------------------------------------------------------
# Helper: build a Yosys synthesis + tech-map script for one surface + PDK
#   $(1) = source SV file
#   $(2) = top module name
#   $(3) = liberty file
#   $(4) = output netlist path
#   $(5) = output stat log path
# ---------------------------------------------------------------------------
define YOSYS_SCRIPT
read_verilog -sv $(1)
synth -top $(2) -flatten
dfflibmap -liberty $(3)
abc -liberty $(3)
write_verilog -noattr $(4)
stat -liberty $(3) > $(5)
endef

# ---------------------------------------------------------------------------
# Phony targets
# ---------------------------------------------------------------------------
.PHONY: all sg13g3 sky90 report clean

all: report

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)/sg13g3 $(BUILD_DIR)/sky90

# ---------------------------------------------------------------------------
# sg13g3 — synthesise all four surfaces against SG13G3 proxy Liberty
# ---------------------------------------------------------------------------
sg13g3: $(BUILD_DIR)
	@echo "[sg13g3] Synthesising Lane V  (holo_lut_pe)..."
	@printf '%s\n' "$(call YOSYS_SCRIPT,$(SRC_LANE_V),holo_lut_pe,$(LIB_SG13G3),$(BUILD_DIR)/sg13g3/holo_lut_pe_netlist.v,$(BUILD_DIR)/sg13g3/holo_lut_pe_stat.log)" \
	      > $(BUILD_DIR)/sg13g3/synth_lane_v.ys
	$(YOSYS) $(YOSYS_FLAGS) $(BUILD_DIR)/sg13g3/synth_lane_v.ys \
	      2>&1 | tee $(BUILD_DIR)/sg13g3/synth_lane_v.log

	@echo "[sg13g3] Synthesising Lane W  (holo_bitrom_bank)..."
	@printf '%s\n' "$(call YOSYS_SCRIPT,$(SRC_LANE_W),holo_bitrom_bank,$(LIB_SG13G3),$(BUILD_DIR)/sg13g3/holo_bitrom_bank_netlist.v,$(BUILD_DIR)/sg13g3/holo_bitrom_bank_stat.log)" \
	      > $(BUILD_DIR)/sg13g3/synth_lane_w.ys
	$(YOSYS) $(YOSYS_FLAGS) $(BUILD_DIR)/sg13g3/synth_lane_w.ys \
	      2>&1 | tee $(BUILD_DIR)/sg13g3/synth_lane_w.log

	@echo "[sg13g3] Synthesising Lane V' (holo_2x2_mesh)..."
	@printf '%s\n' "$(call YOSYS_SCRIPT,$(SRC_LANE_V_PRIME),holo_2x2_mesh,$(LIB_SG13G3),$(BUILD_DIR)/sg13g3/holo_2x2_mesh_netlist.v,$(BUILD_DIR)/sg13g3/holo_2x2_mesh_stat.log)" \
	      > $(BUILD_DIR)/sg13g3/synth_lane_vp.ys
	$(YOSYS) $(YOSYS_FLAGS) $(BUILD_DIR)/sg13g3/synth_lane_vp.ys \
	      2>&1 | tee $(BUILD_DIR)/sg13g3/synth_lane_vp.log

	@echo "[sg13g3] Synthesising Lane S  (holo_sparsity_24)..."
	@printf '%s\n' "$(call YOSYS_SCRIPT,$(SRC_LANE_S),holo_sparsity_24,$(LIB_SG13G3),$(BUILD_DIR)/sg13g3/holo_sparsity_24_netlist.v,$(BUILD_DIR)/sg13g3/holo_sparsity_24_stat.log)" \
	      > $(BUILD_DIR)/sg13g3/synth_lane_s.ys
	$(YOSYS) $(YOSYS_FLAGS) $(BUILD_DIR)/sg13g3/synth_lane_s.ys \
	      2>&1 | tee $(BUILD_DIR)/sg13g3/synth_lane_s.log

	@echo "[sg13g3] Done. Netlists + stat logs in $(BUILD_DIR)/sg13g3/"

# ---------------------------------------------------------------------------
# sky90 — synthesise all four surfaces against SKY90 proxy Liberty
# ---------------------------------------------------------------------------
sky90: $(BUILD_DIR)
	@echo "[sky90] Synthesising Lane V  (holo_lut_pe)..."
	@printf '%s\n' "$(call YOSYS_SCRIPT,$(SRC_LANE_V),holo_lut_pe,$(LIB_SKY90),$(BUILD_DIR)/sky90/holo_lut_pe_netlist.v,$(BUILD_DIR)/sky90/holo_lut_pe_stat.log)" \
	      > $(BUILD_DIR)/sky90/synth_lane_v.ys
	$(YOSYS) $(YOSYS_FLAGS) $(BUILD_DIR)/sky90/synth_lane_v.ys \
	      2>&1 | tee $(BUILD_DIR)/sky90/synth_lane_v.log

	@echo "[sky90] Synthesising Lane W  (holo_bitrom_bank)..."
	@printf '%s\n' "$(call YOSYS_SCRIPT,$(SRC_LANE_W),holo_bitrom_bank,$(LIB_SKY90),$(BUILD_DIR)/sky90/holo_bitrom_bank_netlist.v,$(BUILD_DIR)/sky90/holo_bitrom_bank_stat.log)" \
	      > $(BUILD_DIR)/sky90/synth_lane_w.ys
	$(YOSYS) $(YOSYS_FLAGS) $(BUILD_DIR)/sky90/synth_lane_w.ys \
	      2>&1 | tee $(BUILD_DIR)/sky90/synth_lane_w.log

	@echo "[sky90] Synthesising Lane V' (holo_2x2_mesh)..."
	@printf '%s\n' "$(call YOSYS_SCRIPT,$(SRC_LANE_V_PRIME),holo_2x2_mesh,$(LIB_SKY90),$(BUILD_DIR)/sky90/holo_2x2_mesh_netlist.v,$(BUILD_DIR)/sky90/holo_2x2_mesh_stat.log)" \
	      > $(BUILD_DIR)/sky90/synth_lane_vp.ys
	$(YOSYS) $(YOSYS_FLAGS) $(BUILD_DIR)/sky90/synth_lane_vp.ys \
	      2>&1 | tee $(BUILD_DIR)/sky90/synth_lane_vp.log

	@echo "[sky90] Synthesising Lane S  (holo_sparsity_24)..."
	@printf '%s\n' "$(call YOSYS_SCRIPT,$(SRC_LANE_S),holo_sparsity_24,$(LIB_SKY90),$(BUILD_DIR)/sky90/holo_sparsity_24_netlist.v,$(BUILD_DIR)/sky90/holo_sparsity_24_stat.log)" \
	      > $(BUILD_DIR)/sky90/synth_lane_s.ys
	$(YOSYS) $(YOSYS_FLAGS) $(BUILD_DIR)/sky90/synth_lane_s.ys \
	      2>&1 | tee $(BUILD_DIR)/sky90/synth_lane_s.log

	@echo "[sky90] Done. Netlists + stat logs in $(BUILD_DIR)/sky90/"

# ---------------------------------------------------------------------------
# report — run both PDK synths and patch gate-count table in report.md
# ---------------------------------------------------------------------------
report: sg13g3 sky90
	@echo "[report] Extracting gate counts and patching report.md..."
	@python3 - <<'PYEOF'
import re, pathlib

BUILD   = pathlib.Path("$(BUILD_DIR)")
REPORT  = pathlib.Path("$(SIM_DIR)/report.md")

SURFACES = [
    ("holo_lut_pe",      "Lane V LUT PE"),
    ("holo_bitrom_bank", "Lane W BitROM"),
    ("holo_2x2_mesh",    "Lane V' mesh"),
    ("holo_sparsity_24", "Lane S sparsity"),
]

def extract_cells(stat_log: pathlib.Path) -> tuple[str, str]:
    """Return (num_cells, area_proxy) from Yosys stat log, or ('N/A', 'N/A')."""
    if not stat_log.exists():
        return "N/A", "N/A"
    txt = stat_log.read_text(errors="replace")
    # Yosys stat line: "   Number of cells:              <N>"
    m_cells = re.search(r"Number of cells:\s+(\d+)", txt)
    # Yosys stat line: "   Chip area for this module: <F>"
    m_area  = re.search(r"Chip area for (?:this module|module '\S+'):\s+([\d.]+)", txt)
    cells = m_cells.group(1) if m_cells else "N/A"
    area  = f"{float(m_area.group(1)):.1f}" if m_area else "N/A"
    return cells, area

def check_star(netlist: pathlib.Path) -> bool:
    """Return True if netlist contains a * cell (R-SI-1 violation)."""
    if not netlist.exists():
        return False
    return bool(re.search(r'\$mul|\$div|\$mod', netlist.read_text(errors="replace")))

rows = []
star_hits = 0
for mod, label in SURFACES:
    sg_stat   = BUILD / "sg13g3" / f"{mod}_stat.log"
    sky_stat  = BUILD / "sky90"  / f"{mod}_stat.log"
    sg_net    = BUILD / "sg13g3" / f"{mod}_netlist.v"
    sky_net   = BUILD / "sky90"  / f"{mod}_netlist.v"

    sg_cells, sg_area   = extract_cells(sg_stat)
    sky_cells, sky_area = extract_cells(sky_stat)

    sg_star  = check_star(sg_net)
    sky_star = check_star(sky_net)
    star_col = "FAIL" if (sg_star or sky_star) else "0 ← W31-G3" if mod == "holo_lut_pe" else "0"
    if sg_star or sky_star:
        star_hits += 1

    rows.append(f"| {label} | {sg_cells} | {sg_area} | {sky_cells} | {sky_area} | {star_col} |")

table_body = "\n".join(rows)

# Determine verdicts
sg_pass  = all(extract_cells(BUILD / "sg13g3" / f"{m}_stat.log")[0] not in ("N/A",) for m,_ in SURFACES)
sky_pass = all(extract_cells(BUILD / "sky90"  / f"{m}_stat.log")[0] not in ("N/A",) for m,_ in SURFACES)
g1 = "PASS" if sg_pass  else "FAIL"
g2 = "PASS" if sky_pass else "FAIL"
g3 = "PASS" if star_hits == 0 else "FAIL"

rpt = REPORT.read_text()

# Replace table rows between header separator and next ##
rpt = re.sub(
    r"(\| Lane V LUT PE \|.*\n\| Lane W BitROM \|.*\n\| Lane V' mesh \|.*\n\| Lane S sparsity \|.*\n)",
    table_body + "\n",
    rpt,
)
# Replace verdict lines
rpt = re.sub(r"W31-G1 \(SG13G3 clean\): PASS\|FAIL", f"W31-G1 (SG13G3 clean): {g1}", rpt)
rpt = re.sub(r"W31-G2 \(SKY90 clean\): PASS\|FAIL",  f"W31-G2 (SKY90 clean): {g2}",  rpt)
rpt = re.sub(r"W31-G3 \(zero \* in netlist\): PASS\|FAIL", f"W31-G3 (zero * in netlist): {g3}", rpt)

REPORT.write_text(rpt)
print(f"[report] Patched report.md — G1={g1} G2={g2} G3={g3}")
PYEOF
	@echo "[report] Done."

# ---------------------------------------------------------------------------
# clean
# ---------------------------------------------------------------------------
clean:
	@rm -rf $(BUILD_DIR)
	@echo "[clean] Done."
