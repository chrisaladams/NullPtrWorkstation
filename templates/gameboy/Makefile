# __NAME__ — Game Boy ROM built with GBDK-2020's lcc (SDCC), never with native GCC.
#
#   make                 Debug ROM:   build/debug/__NAME__.gb   (+ .cdb/.noi/.map for C source debugging)
#   make CONFIG=release  Release ROM: build/release/__NAME__.gb
#   make clean
#
GBDK_HOME ?= /opt/gbdk
LCC       := $(GBDK_HOME)/bin/lcc
CONFIG    ?= debug
TARGET    := __NAME__
ROMTITLE  := __ROMTITLE__

BUILD := build/$(CONFIG)
SRCS  := $(wildcard src/*.c)
OBJS  := $(patsubst src/%.c,$(BUILD)/%.o,$(SRCS))
ROM   := $(BUILD)/$(TARGET).gb

ifeq ($(CONFIG),debug)
  # -debug: SDCC --debug + linker .cdb (C source debug info), .noi symbols, .map and .lst listings.
  # Emulicious reads the .cdb next to the ROM for C breakpoints, stepping and variables.
  CFLAGS := -debug -Wf--fverbose-asm
else ifeq ($(CONFIG),release)
  CFLAGS := -Wf--max-allocs-per-node50000
else
  $(error CONFIG must be debug or release)
endif
CFLAGS  += -Wa-l
LDFLAGS := -Wm-yn"$(ROMTITLE)" -Wl-m

.PHONY: all clean run
all: $(ROM)

$(BUILD):
	mkdir -p $@

$(BUILD)/%.o: src/%.c | $(BUILD)
	$(LCC) $(CFLAGS) -c -o $@ $<

$(ROM): $(OBJS) | $(BUILD)
	$(LCC) $(CFLAGS) $(LDFLAGS) -o $@ $(OBJS)

clean:
	rm -rf build
