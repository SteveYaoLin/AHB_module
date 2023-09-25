
# Makefile for compiling and simulating AHB bus RTL and testbench
# Usage: make              (Compile and run simulation)
#        make clean        (Clean up)
#        make wave         (Open waveform viewer)
#        make log          (View simulation log)

# Simulation settings
SIMULATOR = VCS # Replace with your simulator (e.g., ModelSim, VCS)

# Source files
RTL_FILES = filelist.f
TB_FILES = testlist.f 
TOP_MODULE = ahb_sram

# Compilation options
#SV_COMPILE_FLAGS = +incdir+include_dir +define+SIMULATION  # Add include directories and defines as needed
# Compilation options
SV_COMPILE_FLAGS = -I./RTL -I./test +define+SIMULATION

# Simulation options
SIMULATION_FLAGS = +access+r +define+DEBUG

# Log and waveform viewer
LOG_FILE = simulation.log
WAVEFORM_VIEWER = verdi
WAVEFORM_FILE = dump.fsdb
# Targets
all: compile run

compile:
    $(SIMULATOR) $(SV_COMPILE_FLAGS) $(RTL_FILES) $(TB_FILES) -top $(TOP_MODULE)

run:
    ./simv $(SIMULATION_FLAGS) | tee $(LOG_FILE)

clean:
    rm -rf simv csrc $(LOG_FILE) $(WAVEFORM_FILE)

wave:
    $(WAVEFORM_VIEWER) -sv -f $(WAVEFORM_FILE) &

.PHONY: all compile run clean wave