# Wave-33 Lane T TENET skip-rate probe — iverilog SIM only.
# Anchor: phi^2 + phi^-2 = 3 · DOI 10.5281/zenodo.19227877

DUT     := ../../rtl/holo_sparse_skip.sv
PROBE   := probe.sv
BUILD   := build
BIN     := $(BUILD)/probe.vvp
LOG     := $(BUILD)/probe.log
SV2V    := /tmp/sv2v-Linux/sv2v

all: run

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/holo_sparse_skip.v: $(DUT) | $(BUILD)
	$(SV2V) $(DUT) > $@

$(BUILD)/probe.v: $(PROBE) | $(BUILD)
	$(SV2V) $(PROBE) > $@

$(BIN): $(BUILD)/holo_sparse_skip.v $(BUILD)/probe.v
	iverilog -g2012 -o $@ $^

run: $(BIN)
	vvp $(BIN) | tee $(LOG)

clean:
	rm -rf $(BUILD)
