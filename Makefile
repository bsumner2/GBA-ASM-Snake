ifeq '$(PROJ_NAME)' ''
	PROJ_NAME=$(shell pwd | sed 's-[a-zA-Z/]*/--g')
endif

TARGET=$(PROJ_NAME)
ASM=./asm
INC=./include
BIN=./bin
S_OBJS=$(shell find ./asm -iname *.s -type f | sed 's/\.s/\.o/g' | sed 's-/asm-/bin-g')
AS=arm-none-eabi-gcc
LD=$(AS)
ASFLAGS=-xassembler-with-cpp -I$(INC)
LDFLAGS=-mthumb-interwork -mthumb -specs=gba.specs
OBJ_CPY=arm-none-eabi-objcopy

.PHONY: build clean

.SILENT:



test: $(ASM) $(BIN) clean build
	mgba-qt $(BIN)/$(TARGET).gba

build: $(ASM) $(BIN) $(TARGET).gba

$(ASM) $(BIN):
	mkdir -p $@

$(TARGET).gba: $(TARGET).elf
	$(OBJ_CPY) -v -O binary $(BIN)/$< $(BIN)/$@
	-@gbafix $(BIN)/$@

$(TARGET).elf: $(S_OBJS)
	$(LD) $^ $(LDFLAGS) -o $(BIN)/$@

$(S_OBJS): $(BIN)/%.o : $(ASM)/%.s
	$(AS) $(ASFLAGS) -c $< -o $@

clean: $(ASM) $(BIN)
	@rm -fv $(BIN)/*.{elf,o,gba}

clr_sram:
	@rm -fv $(BIN)/*.sav

