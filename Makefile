ifeq '$(PROJ_NAME)' ''
	PROJ_NAME=$(shell pwd | sed 's-[a-zA-Z/]*/--g')
endif

TARGET=$(PROJ_NAME)
ASM=./asm
BIN=./bin
S_OBJS=$(shell find ./asm -iname *.s -type f | sed 's/\.s/\.o/g' | sed 's-/asm-/bin-g')
AS=arm-none-eabi-gcc
LD=$(AS)
ASFLAGS=-xassembler-with-cpp
LDFLAGS=-mthumb-interwork -mthumb -specs=gba.specs
OBJ_CPY=arm-none-eabi-objcopy
OBJ_DUMP=arm-none-eabi-objdump

.PHONY: build clean

.SILENT:



test: build_dirs clean build
	mgba-qt $(BIN)/$(TARGET).gba

build: build_dirs $(TARGET).gba

build_dirs: $(ASM) $(BIN)

dump_objs: 

dump_elf: $(TARGET).elf
	$(OBJ_DUMP

	

$(ASM) $(BIN):
	mkdir -p $@

$(TARGET).gba: $(TARGET).elf
	$(OBJ_CPY) -v -O binary $(BIN)/$< $(BIN)/$@
	-@gbafix $(BIN)/$@

$(TARGET).elf: $(S_OBJS)
	$(LD) $^ $(LDFLAGS) -o $(BIN)/$@

$(S_OBJS): $(BIN)/%.o : $(ASM)/%.s
	$(AS) $(ASFLAGS) -c $< -o $@

clean: $(BIN)
	@rm -fv $</*.{elf,o,gba}

clr_sram: $(BIN)
	@rm -fv $</*.sav

