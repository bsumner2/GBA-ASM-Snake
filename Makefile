ifeq '$(PROJ_NAME)' ''
	PROJ_NAME=$(shell pwd | sed 's-[a-zA-Z/]*/--g')
endif



TARGET=$(PROJ_NAME)
GTARGET=Debug_$(PROJ_NAME)

MGBA=/mnt/c/Program\ Files/mGBA/mGBA.exe

ASM=./asm
BIN=./bin

S_OBJS=$(shell find ./asm -iname *.s -type f | sed 's/\.s/\.o/g' | sed 's-/asm-/bin-g')
GS_OBJS=$(shell find ./asm -iname *.s -type f | sed 's/\.s/\.o/g' | sed 's-/asm/-/bin/debug_-g')

AS=arm-none-eabi-gcc
GDB=arm-none-eabi-gdb
LD=$(AS)
ASFLAGS=-xassembler-with-cpp
LDFLAGS=-mthumb-interwork -mthumb -specs=gba.specs
GASFLAGS=$(ASFLAGS) -g
GLDFLAGS=$(LDFLAGS) -g
OBJ_CPY=arm-none-eabi-objcopy
OBJ_DUMP=arm-none-eabi-objdump

.PHONY: build clean

.SILENT:

test: build_dirs clean build
	$(MGBA) $(BIN)/$(TARGET).gba

build: build_dirs clean $(TARGET).gba

build_dirs: $(ASM) $(BIN)

debug: debug_build
	$(MGBA) -g $(BIN)/$(GTARGET).elf &
	$(GDB) $(BIN)/$(GTARGET).elf -ex "target remote 172.23.160.1:2345"

debug_build: build_dirs clean $(GTARGET).gba


$(ASM) $(BIN):
	mkdir -p $@


$(GTARGET).gba: $(GTARGET).elf
	$(OBJ_CPY) -v -O binary $(BIN)/$< $(BIN)/$@
	-@gbafix $(BIN)/$@


$(TARGET).gba: $(TARGET).elf
	$(OBJ_CPY) -v -O binary $(BIN)/$< $(BIN)/$@
	-@gbafix $(BIN)/$@


$(GTARGET).elf: $(GS_OBJS)
	$(LD) $^ $(GLDFLAGS) -o $(BIN)/$@


$(TARGET).elf: $(S_OBJS)
	$(LD) $^ $(LDFLAGS) -o $(BIN)/$@


$(GS_OBJS): $(BIN)/debug_%.o : $(ASM)/%.s
	$(AS) $(GASFLAGS) -c $< -o $@


$(S_OBJS): $(BIN)/%.o : $(ASM)/%.s
	$(AS) $(ASFLAGS) -c $< -o $@

clean: $(BIN)
	@rm -fv $</*.{elf,o,gba}

clr_sram: $(BIN)
	@rm -fv $</*.sav

