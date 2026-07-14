# Minimal FFmpeg size matrix for Daggermap / kineticon.
#
#   make sizes              # build all presets, write SIZE_REPORT.md
#   make build PRESET=h264  # one preset
#   make clean              # wipe out/
#   make clean-all          # wipe out/ and src/ build trees

ROOT     := $(abspath .)
SRC      := $(ROOT)/src
OUT      := $(ROOT)/out
SCRIPTS  := $(ROOT)/scripts
CONFIGS  := $(ROOT)/configs

PRESETS ?= h264 h264_vp8 h264_vp8_vp9 h264_vp8_vp9_extra h264_vp8_vp9_extra_images
PRESET  ?= h264

JOBS ?= $(shell nproc 2>/dev/null || echo 4)

.PHONY: all sizes build clean clean-all check-src report help

all: sizes

help:
	@echo "Presets: $(PRESETS)"
	@echo "  make build PRESET=<name>"

check-src:
	@test -x $(SRC)/configure || { \
		echo "Missing $(SRC)/configure — clone FFmpeg first:"; \
		echo "  git clone --depth 1 --branch n7.1 https://github.com/FFmpeg/FFmpeg.git src"; \
		exit 1; \
	}

build: check-src
	$(SCRIPTS)/build_preset.sh $(PRESET)

report:
	$(SCRIPTS)/size_report.sh > $(ROOT)/SIZE_REPORT.md
	@cat $(ROOT)/SIZE_REPORT.md

clean:
	rm -rf $(OUT)

clean-all: clean
	rm -rf $(SRC)/ffbuild-* $(SRC)/build-*
