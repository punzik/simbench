PROJECT := fw
SOURCES := crt0.s main.c uprintf.c md5.c
CPU_RAM_REG := ram_reg

ARCH    := riscv32-none-elf
CFLAGS  := -O2 -Wall -march=rv32i -mabi=ilp32 -mstrict-align \
           -nostartfiles -ffunction-sections -lgcc \
           -Wl,-Tpicorv32-minimal.ld,-static,-Map,$(PROJECT).map

ELF = $(PROJECT).elf
BIN = $(PROJECT).bin
ASM = $(PROJECT).asm
SVH = $(PROJECT).svh
MEM = $(PROJECT).mem

all: $(ELF) $(BIN) $(MEM) Makefile

$(ELF): $(SOURCES) picorv32-minimal.ld Makefile
	$(ARCH)-gcc $(CFLAGS) -o $(ELF) $(SOURCES)

$(BIN): $(ELF)
	$(ARCH)-objcopy -O binary $(ELF) $(BIN)

$(SVH): $(BIN)
	../../scripts/bin2initial.scm $(BIN) $(CPU_RAM_REG) > $(SVH)

$(MEM): $(BIN)
	../../scripts/bin2mem.scm $(BIN) 65536 > $(MEM)

disasm: $(ASM)
$(ASM): $(ELF)
	$(ARCH)-objdump -d $(ELF) > $(ASM)

clean:
	rm -f $(ELF) $(BIN) $(PROJECT).map $(SVH) $(MEM)
