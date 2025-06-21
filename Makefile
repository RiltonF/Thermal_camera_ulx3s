# ==== Project config ====
TOP        ?= top
#LFE5U-25F for ULX3S v3.0.3
DEVICE      := 25
PACKAGE     := CABGA381
LPF         := src/constraints/ulx3s_v20_edited.lpf
# SV_SOURCES  := $(wildcard src/**/*.sv) $(wildcard src/*.sv)
SV_SOURCES  := $(wildcard src/*.sv) $(wildcard src/misc/*.sv) $(wildcard src/mem/*.v)
VHD_SOURCES := $(wildcard src/misc/*.vhd)
V_SOURCES   := $(wildcard src/**/*.v) $(wildcard src/*.v)
V_BLACKBOX  := $(wildcard src/misc/*.sv)
SV_MEMORY    := $(wildcard src/memory/*.sv)
BUILD_DIR   := build
CLOCKS_DIR  := $(BUILD_DIR)/clocks

# ==== Generated files ====
JSON       := $(BUILD_DIR)/$(TOP).json
ASC        := $(BUILD_DIR)/$(TOP).asc
BIT        := $(BUILD_DIR)/$(TOP).bit

# ==== Tools ====
# using oss-cad so the tools are setup and sourcing them with direnv
VHDL2VL ?= vhd2vl
SV2V ?= sv2v 
YOSYS ?= yosys
NEXTPNR-ECP5 ?= nextpnr-ecp5
ECPPACK ?= ecppack
ECPPLL ?= ecppll
OPENFPGALOADER ?= openFPGALoader  

# clock generator
CLK0_NAME ?= clk_vga_ddr
CLK0_FILE_NAME ?= $(CLOCKS_DIR)/$(CLK0_NAME).v
CLK0_OPTIONS ?= --clkin 25 --clkout0 125 --clkout1 25 --phase1 0
CLK1_NAME ?= clk_vga_sdr
CLK1_FILE_NAME ?= $(CLOCKS_DIR)/$(CLK1_NAME).v
CLK1_OPTIONS ?= --clkin 25 --clkout0 250 --clkout1 25 --phase1 0
CLK2_NAME ?= clk_sdram
CLK2_FILE_NAME ?= $(CLOCKS_DIR)/$(CLK2_NAME).v
CLK2_OPTIONS ?= --clkin 25 --clkout0 100 --clkout1 100 --phase1 90
# CLK2_OPTIONS ?= --clkin 25 --clkout0 142.857 --clkout1 142.857 --phase1 90
CLK3_NAME ?= clk3
CLK3_FILE_NAME ?= $(CLOCKS_DIR)/$(CLK3_NAME).v
CLK3_OPTIONS ?= --clkin 25 --clkout0 250 --clkout1 250 --phase1 0 --clkout2 125 --phase2 0
CLK_SOURCES := $(CLK0_FILE_NAME) $(CLK1_FILE_NAME) $(CLK2_FILE_NAME) $(CLK3_FILE_NAME)

# ==== Default target ====
all: $(BIT)

# ==== Generate PLL Clocks ====
$(CLK0_FILE_NAME): $(BUILD_DIR)
	$(ECPPLL) $(CLK0_OPTIONS) -n $(CLK0_NAME) --file $@

$(CLK1_FILE_NAME): $(BUILD_DIR)
	$(ECPPLL) $(CLK1_OPTIONS) -n $(CLK1_NAME) --file $@

$(CLK2_FILE_NAME): $(BUILD_DIR)
	$(ECPPLL) $(CLK2_OPTIONS) -n $(CLK2_NAME) --file $@

$(CLK3_FILE_NAME): $(BUILD_DIR)
	$(ECPPLL) $(CLK3_OPTIONS) -n $(CLK3_NAME) --file $@

# ==== Build steps ====
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
	mkdir -p $(CLOCKS_DIR)

# VHDL to VERILOG conversion
# convert all *.vhd filenames to .v extension
VHDL_TO_VERILOG_FILES ?= $(VHD_SOURCES:.vhd=.v)
# implicit conversion rule
%.v: %.vhd
	$(VHDL2VL) $< $@

HDL_SOURCES := $(TOP).sv $(CLK_SOURCES) $(V_SOURCES) $(SV_SOURCES)

$(JSON): $(HDL_SOURCES) | $(BUILD_DIR)
	$(YOSYS) -l build/yosys.log \
		-m slang \
		-p "read_verilog $(CLK_SOURCES) $(VHDL_TO_VERILOG_FILES)" $(V_SOURCES) \
		-p "read -sv $(SV_MEMORY)" \
		-p "read_slang --ignore-unknown-modules\
		-I src/ -I src/memory -I build/clocks \
		--top $(TOP) \
		  $(SV_SOURCES) $(TOP).sv \
		--keep-hierarchy " \
		-p 'synth_ecp5 -json $(JSON)'

$(ASC): $(JSON)
	$(NEXTPNR-ECP5) -l build/nextpnr.log \
		--report build/timing.rpt --detailed-timing-report -v \
		--${DEVICE}k --speed 8 \
		--package $(PACKAGE) \
		--json $(JSON) \
		--lpf $(LPF) \
		--textcfg $(ASC) || FAILED=1; \
		jq . build/timing.rpt > build/timing.json; \
		if [ "$$FAILED" = "1" ]; then echo "ERROR: PNR failed."; exit 1; fi

$(BIT): $(ASC)
	$(ECPPACK) $(ASC) $(BIT)

clocks: $(CLK_SOURCES)

# ==== Upload using openFPGALoader ====
upload: $(BIT)
	$(OPENFPGALOADER) --board ulx3s $(BIT)

flash: $(BIT)
	$(OPENFPGALOADER) --board ulx3s --file-type bin -f $(BIT)

# ==== Cleanup ====
clean:
	rm -rf $(BUILD_DIR)

.PHONY: all al clean cl upload up clocks flash fl

al: all
cl: clean
up: upload
fl: flash
