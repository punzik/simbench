TOP_MODULE = top

SOURCES = top.sv
FLAGS_FILE = ../source/sources.f
INCLUDES =
PARAMS :=
THREADS := 1

FLAGS = -Wno-WIDTH --top-module $(TOP_MODULE) +1800-2017ext+sv \
	--timing --Mdir $(TOP_MODULE) -o $(TOP_MODULE) -f $(FLAGS_FILE) \
	$(PARAMS) --timescale "1ps/1ps" --threads $(THREADS) -j 0

# FLAGS += --trace

all: $(SOURCES)
	verilator $(FLAGS) --binary $(INCLUDES) $(SOURCES)

clean:
	rm -rf $(TOP_MODULE)
