TOP_MODULE = testbench

SOURCES = top.cpp clock_generator.cpp
FLAGS_FILE = ../source/sources.f
INCLUDES =

FLAGS = -Wno-WIDTH -cc --top-module $(TOP_MODULE) +1800-2017ext+sv \
	--timing --Mdir $(TOP_MODULE) -o $(TOP_MODULE) -f $(FLAGS_FILE) \
	--timescale "1ps/1ps" --threads 1

# FLAGS += --trace

all: $(SOURCES)
	verilator $(FLAGS) --exe --build $(INCLUDES) $(SOURCES)

clean:
	rm -rf $(TOP_MODULE)
