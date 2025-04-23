# ==== Project config ====
TOP        ?= top
#LFE5U-25F for ULX3S v3.0.3
DEVICE      := 25
PACKAGE     := CABGA381
LPF         := ../constraints/ulx3s_v20_edited.lpf
# SV_SOURCES  := $(wildcard src/**/*.sv) $(wildcard src/*.sv)
SV_SOURCES  := $(wildcard src/*.sv)
V_SOURCES   := $(wildcard src/**/*.v) $(wildcard src/*.v)
V_BLACKBOX  := $(wildcard src/misc/*.sv)
SV_MEMORY    := $(wildcard src/memory/*.sv)
HDL_SOURCES := $(SYNTH_V) $(V_SOURCES) $(SV_SOURCES)
BUILD_DIR   := build
CLOCKS_DIR  := $(BUILD_DIR)/clocks

# ==== Generated files ====
SYNTH_V    := $(BUILD_DIR)/$(TOP)_synth.v
JSON       := $(BUILD_DIR)/$(TOP).json
ASC        := $(BUILD_DIR)/$(TOP).asc
BIT        := $(BUILD_DIR)/$(TOP).bit

# ==== Tools ====
# using oss-cad so the tools are setup and sourcing them with direnv
SV2V ?= sv2v 
YOSYS ?= yosys
NEXTPNR-ECP5 ?= nextpnr-ecp5
ECPPACK ?= ecppack
ECPPLL ?= ecppll
OPENFPGALOADER ?= openFPGALoader  

# clock generator
CLK0_NAME ?= clk0
CLK0_FILE_NAME ?= $(CLOCKS_DIR)/$(CLK0_NAME).v
CLK0_OPTIONS ?= --clkin 25 --clkout0 100 --clkout1 50 --phase1 0 --clkout2 25 --phase2 0 --clkout3 125 --phase3 0
CLK1_NAME ?= clk1
CLK1_FILE_NAME ?= $(CLOCKS_DIR)/$(CLK1_NAME).v
CLK1_OPTIONS ?= --clkin 25 --clkout0 250 --clkout1 25 --phase1 0
CLK2_NAME ?= clk2
CLK2_FILE_NAME ?= $(CLOCKS_DIR)/$(CLK2_NAME).v
CLK2_OPTIONS ?= --clkin 25 --clkout0 125 --clkout1 25 --phase1 0
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

$(SYNTH_V): $(SV_SOURCES) | $(BUILD_DIR)
	$(SV2V) $(SV_SOURCES) > $(SYNTH_V)
#	cat $(V_SOURCES) >> $(SYNTH_V)


$(info TOP = $(TOP))
$(info JSON = $(JSON))
$(info SV_SOURCES = $(SV_SOURCES))

$(JSON): $(SV_SOURCES) | $(BUILD_DIR)
	$(YOSYS) -l build/yosys.log \
		-m slang \
		-p "read_verilog $(CLK_SOURCES) " \
		-p "read -sv $(SV_MEMORY)" \
		-p "read_slang --ignore-unknown-modules\
		-I src/ -I src/memory -I build/clocks \
		--top top \
		  $(SV_SOURCES) top.sv \
		--keep-hierarchy " \
		-p 'synth_ecp5 -json $(JSON)'

# --top top --allow-dup-initial-drivers --allow-use-before-declare --ignore-unknown-modules \
# -p "read_verilog $(V_BLACKBOX)" \
# --top top --allow-dup-initial-drivers --allow-use-before-declare --ignore-unknown-modules \
# --top top -D SYNTHESIS --allow-use-before-declare --ignore-unknown-modules \
# $(JSON): $(SV_SOURCES) | $(BUILD_DIR)
# -p "read_slang --ignore-unknown-modules --allow-use-before-declare $(SV_SOURCES) top.sv --top top" \
# 	$(YOSYS) -l build/yosys.log \
# 		-m slang \
# 		-f slang \
# 		-p "read_verilog $(CLK_SOURCES) $(V_BLACKBOX)" \
# 		-p "read_verilog -sv $(V_MEMORY)" \
# 		-p "read_slang --ignore-initial $(SV_SOURCES) " \
# 		-p "synth_ecp5 -top $(TOP).sv -json $(JSON)"
		
# $(JSON): $(SV_SOURCES) | $(BUILD_DIR)
# 	$(YOSYS) \
# 		-p "plugin -i slang" \
# 		-p "synth_ecp5 -top $(TOP) -json $(JSON)" \
# 		-p "read -vlog2k $(CLK_SOURCES)" \
# 		-p "read -sv $(SV_SOURCES) --top $(TOP)"

$(ASC): $(JSON)
	$(NEXTPNR-ECP5) \
		--${DEVICE}k --speed 8 \
		--package $(PACKAGE) \
		--json $(JSON) \
		--lpf $(LPF) \
		--textcfg $(ASC)

$(BIT): $(ASC)
	$(ECPPACK) $(ASC) $(BIT)

clocks: $(CLK_SOURCES)

# ==== Upload using openFPGALoader ====
upload: $(BIT)
	$(OPENFPGALOADER) --board ulx3s $(BIT)

# ==== Cleanup ====
clean:
	rm -rf $(BUILD_DIR)

.PHONY: all al clean cl upload up clocks

al: all
cl: clean
up: upload
