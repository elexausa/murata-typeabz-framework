#  d88888b db      d88888b db    db  .d8b.
#  88'     88      88'     `8b  d8' d8' `8b
#  88ooooo 88      88ooooo  `8bd8'  88ooo88
#  88~~~~~ 88      88~~~~~  .dPYb.  88~~~88 
#  88.     88booo. 88.     .8P  Y8. 88   88
#  Y88888P Y88888P Y88888P YP    YP YP   YP
# 
#  Makefile for building STM32L082CZYx ARM 
#  Cortex-M0+ firmware.
#
#  Author: Alex Bennett

# Don't touch this
SHELL = /bin/sh

# Build configuration
VERSION = "0.0.1"

# Debug flag
DEBUG = 1

# Target information
TARGET = murata-typeabz
CPU = cortex-m0plus

# Manual directories
BUILD_DIR 	:= build
SRC_DIR		:= src
INC_DIR		:= inc
LIB_DIR 	:= lib

# Tools
PREFIX = arm-none-eabi
CC := $(PREFIX)-gcc
AS := $(CC) -x assembler-with-cpp
CP := $(PREFIX)-objcopy
SZ := $(PREFIX)-size
LD := $(PREFIX)-ld

# Linker script
LD_SCRIPT = STM32L082CZYx_FLASH.ld

## ------------------------------------------------------------
## Makefile setup
## ------------------------------------------------------------

# -------------------------------------------------------------
# Definitions
# -------------------------------------------------------------  

DEFS = \
-DSTM32L082xx \
-DUSE_HAL_DRIVER

# -------------------------------------------------------------
# Build Type Modifiers
# -------------------------------------------------------------

# Debug
DEFS_DEBUG			= -DDEBUG
CFLAGS_DEBUG		= -g -gdwarf-2
LDFLAGS_DEBUG		= --specs=rdimon.specs -Og 

# Release
CFLAGS_RELEASE		= -Os
LDFLAGS_RELEASE		= --specs=nosys.specs

# -------------------------------------------------------------
# Apply flag modifiers 
# -------------------------------------------------------------

ifeq ($(DEBUG), 1)
	DEFS += $(DEFS_DEBUG)
	C_FLAGS += $(CFLAGS_DEBUG)
	LD_FLAGS += $(LDFLAGS_DEBUG)
else
	C_FLAGS += $(CFLAGS_RELEASE)
	LD_FLAGS += $(LDFLAGS_RELEASE)
endif

# -------------------------------------------------------------
# File locations
# -------------------------------------------------------------

# Find source files
OBJ_DIR 	:= $(BUILD_DIR)/obj
INC_DIRS	:= $(shell find . -name "*.h" | sed 's|/[^/]*$$||' | sort -u)
C_SRC		:= $(foreach dir, $(SRC_DIR), $(shell find $(dir) -name "*.c" ))
C_SRC		+= $(foreach dir, $(LIB_DIR), $(shell find $(dir) -name "*.c" )) # Add library C source files
ASM_SRC		:= $(foreach dir, $(SRC_DIR), $(shell find $(dir) -name "*.s" ))
ASM_SRC		+= $(foreach dir, $(LIB_DIR), $(shell find $(dir) -name "*.s" )) # Add library assembly source files
OBJECTS		:= $(addprefix $(OBJ_DIR)/, $(C_SRC:.c=.o) $(ASM_SRC:.s=.o))
DIRS		:= $(BUILD_DIR) $(sort $(dir $(OBJECTS)))

# -------------------------------------------------------------
# Compiler Flags 
# -------------------------------------------------------------

# Toolchain settings
TOOLCHAIN_SETTINGS := -mcpu=$(CPU) -mthumb

# Build final CFLAG string
C_FLAGS := $(TOOLCHAIN_SETTINGS) $(DEFS) $(addprefix -I, $(INC_DIRS)) 
C_FLAGS += -Wall 
C_FLAGS += -fdata-sections
C_FLAGS += -ffunction-sections

# -------------------------------------------------------------
# Linker Flags 
# -------------------------------------------------------------

# Build LDFLAG string
LD_FLAGS += $(TOOLCHAIN_SETTINGS) $(DEFS) -specs=nano.specs -T$(LD_SCRIPT) -lc -lm -lnosys -Wl,-Map=$(BUILD_DIR)/$(TARGET).map,--cref -Wl,--gc-sections

# -------------------------------------------------------------
# Functions
# -------------------------------------------------------------

# None

## -------------------------------------------------------------
## Building
## -------------------------------------------------------------

# Expansion for mkdir
dir_create=@mkdir -p $(@D)

# No target specified, run all
.PHONY: all
all: header build flash

# Add C_SRC and ASM_SRC to virtual path
vpath %.c $(sort $(dir $(C_SRC)))
vpath %.s $(sort $(dir $(ASM_SRC)))

# Default
build: $(BUILD_DIR)/$(TARGET).elf $(BUILD_DIR)/$(TARGET).hex $(BUILD_DIR)/$(TARGET).bin

# Build .elf file
$(BUILD_DIR)/$(TARGET).elf: $(OBJECTS) Makefile
	$(CC) $(OBJECTS) $(LD_FLAGS) -o $@
	$(SZ) $@

# Build 
$(OBJ_DIR)/%.o: %.c Makefile
	$(dir_create)
	$(CC) -c $(C_FLAGS) -Wa,-a,-ad,-alms=$(BUILD_DIR)/$(notdir $(<:.c=.lst)) $< -o $@

$(OBJ_DIR)/%.o: %.s Makefile
	$(dir_create)
	$(AS) -c $(C_FLAGS) $< -o $@

# Hex output
$(BUILD_DIR)/%.hex: $(BUILD_DIR)/%.elf
	$(CP) -O ihex $< $@
	
# Binary output.
$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf
	$(CP) -O binary -S $< $@	

## -------------------------------------------------------------
## Utilities
## -------------------------------------------------------------

# Header
header:
	@echo " "
	@echo "d88888b db      d88888b db    db  .d8b. "
	@echo "88'     88      88'     '8b  d8' d8' '8b"
	@echo "88ooooo 88      88ooooo  '8bd8'  88ooo88"
	@echo "88~~~~~ 88      88~~~~~  .dPYb.  88~~~88"
	@echo "88.     88booo. 88.     .8P  Y8. 88   88"
	@echo "Y88888P Y88888P Y88888P YP    YP YP   YP"
	@echo " "
	@echo "     ----- STM32 Build Script -----     "
	@echo " "
	@echo "Target: $(TARGET)"
	@echo "Version: $(VERSION)"
	@echo " "

# Clean up
clean: header
	@echo "----------------------------------------"
	@echo " Cleaning previous build..."
	@echo "----------------------------------------"
	-rm -rf $(BUILD_DIR)
	@echo " "

# Program attached device
flash: build
	@echo "----------------------------------------"
	@echo " Writing to attached STM32L0 device..."
	@echo "----------------------------------------"
	
	#st-flash write $(TARGET).bin 0x08000000