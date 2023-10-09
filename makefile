
# Makefile for compiling and simulating AHB bus RTL and testbench
# Usage: make              (Compile and run simulation)
#        make clean        (Clean up)
#        make wave         (Open waveform viewer)
#        make log          (View simulation log)

# Simulation settings
SIMULATOR = vcs# Replace with your simulator (e.g., ModelSim, VCS)

# Source files
RTL_FILES = filelist.f
TB_FILES = testlist.f 
TOP_MODULE = top_tb 

# Compilation options
SV_COMPILE_FLAGS = -F $(RTL_FILES) -F $(TB_FILES) +define+SIMULATION

# Simulation options
SIMULATION_FLAGS = +access+r +define+DEBUG

# Log and waveform viewer
LOG_FILE = simulation.log
WAVEFORM_VIEWER = verdi
WAVEFORM_FILE = dump.fsdb

# Targets
all: compile run

compile:
		$(SIMULATOR) -sverilog \
				+vcs+lic+wait \
	    		+libext+.v+.vlib+.vh+.vs \
                -full64 -debug_acc+all\
				-F $(RTL_FILES) \
				-F $(TB_FILES)\
				-o simv \
				-top $(TOP_MODULE)
run:
	./simv \
		+fsdb+function \
		-ucli -i test/run.tcl \
		-l $(LOG_FILE)\
	#./simv $(SIMULATION_FLAGS) | tee $(LOG_FILE)

clean:
	rm -rf simv csrc $(LOG_FILE) $(WAVEFORM_FILE)

wave:
	$(WAVEFORM_VIEWER) -sv -f $(WAVEFORM_FILE) &

.PHONY: all compile run clean wave
