# sim/bitrom_ber_probe/Makefile — Wave-29 Lane B · BitROM BER Probe
# Targets: iverilog | verilator | report | clean
# R-SI-1: no * in RTL; Makefile is build glue (not synthesisable RTL)
# Author: Vasilev Dmitrii <admin@t27.ai>
# Refs #108

RTL_DIR   := ../../rtl
SIM_DIR   := .

DUT_SV    := $(RTL_DIR)/holo_bitrom_bank.sv
PROBE_SV  := $(SIM_DIR)/probe.sv

# CI default: 1e6 rounds (fast); offline 1e9 via MAX_ROUNDS override
MAX_ROUNDS ?= 1000000

IVERILOG  := iverilog
VVP       := vvp

VERILATOR := verilator
VER_FLAGS := --binary --sv --timing -Wall \
             -GMAX_ROUNDS=$(MAX_ROUNDS) \
             --top-module bitrom_ber_probe

# Output artefacts
IVERILOG_OUT  := sim_bitrom_ber.vvp
VERILATOR_DIR := obj_dir_ber
REPORT_MD     := report.md

.PHONY: all iverilog verilator report clean

all: iverilog

# ----------------------------------------------------------------
# iverilog target
# ----------------------------------------------------------------
iverilog: $(IVERILOG_OUT)
	$(VVP) $(IVERILOG_OUT) -pMAX_ROUNDS=$(MAX_ROUNDS)

$(IVERILOG_OUT): $(DUT_SV) $(PROBE_SV)
	$(IVERILOG) -g2012 \
	    -DMAX_ROUNDS=$(MAX_ROUNDS) \
	    -o $(IVERILOG_OUT) \
	    $(DUT_SV) \
	    $(PROBE_SV)

# ----------------------------------------------------------------
# verilator target (preferred for 1e9 scale)
# ----------------------------------------------------------------
verilator: $(DUT_SV) $(PROBE_SV)
	$(VERILATOR) $(VER_FLAGS) \
	    -o bitrom_ber_probe \
	    $(DUT_SV) \
	    $(PROBE_SV)
	$(VERILATOR_DIR)/bitrom_ber_probe

# ----------------------------------------------------------------
# report target — emit report.md from sim run
# ----------------------------------------------------------------
report: $(IVERILOG_OUT)
	$(VVP) $(IVERILOG_OUT) -pMAX_ROUNDS=$(MAX_ROUNDS) 2>&1 | \
	    tee /dev/stderr | \
	    awk ' \
	    BEGIN { \
	        print "# BitROM BER Probe — Wave-29 Lane B Report\n"; \
	        print "## Configuration\n"; \
	        print "- DUT: rtl/holo_bitrom_bank.sv from PR #14 (898fc06)"; \
	        print "- Reads simulated: $(MAX_ROUNDS) (CI default 1e6 / offline target 1e9)"; \
	        print "- Seed: LFSR(0xDEADBEEF)"; \
	        print "- Verdict: 🟡 SIM — pending silicon\n"; \
	        print "## Results\n"; \
	    } \
	    /total_reads/  { printf "- total_reads: %s\n",  $$NF } \
	    /total_errors/ { printf "- total_errors: %s\n", $$NF } \
	    /BER/          { printf "- BER: %s %s\n",       $$3, $$4 } \
	    /W28-G3/       { printf "- W28-G3 gate (BER <= 1e-9): %s\n\n", $$NF } \
	    END { \
	        print "## Honest Status\n"; \
	        print "🟡 SIM — silicon-verified 🟢 only on TTIHP27a return 2026-09-30.\n"; \
	        print "> Refs #108 · Anchor: φ² + φ⁻² = 3 · DOI 10.5281/zenodo.19227877"; \
	    }' > $(REPORT_MD)
	@echo "report.md written."

# ----------------------------------------------------------------
# clean
# ----------------------------------------------------------------
clean:
	rm -f $(IVERILOG_OUT)
	rm -rf $(VERILATOR_DIR)
