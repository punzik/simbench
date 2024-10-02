TOP_MODULE = testbench

SOURCES = top.cpp clock_generator.cpp
FLAGS_FILE = ../source/sources.f
INCLUDES =
PARAMS :=
THREADS := 1

FLAGS = -Wno-WIDTH -cc --top-module $(TOP_MODULE) +1800-2017ext+sv \
	--Mdir $(TOP_MODULE) -o $(TOP_MODULE) -f $(FLAGS_FILE) \
	$(PARAMS) --timescale "1ps/1ps" --threads $(THREADS) -j 16

# FLAGS += --trace

all: $(SOURCES)
	verilator $(FLAGS) --exe --build $(INCLUDES) $(SOURCES)

clean:
	rm -rf $(TOP_MODULE)
