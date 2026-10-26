# Builds the CoreAudio / IOKit probe tools into ./bin (Xcode Command Line Tools required).
BIN   := bin
SWIFT := audioprops running setdefault hidden
C     := usbdesc usbreenum
ALL   := $(addprefix $(BIN)/,$(SWIFT) $(C))

all: $(ALL) $(BIN)/tone.wav

$(BIN)/%: tools/src/%.swift | $(BIN)
	swiftc -O -o $@ $<

$(BIN)/%: tools/src/%.c | $(BIN)
	clang -O2 -o $@ $< -framework CoreFoundation -framework IOKit

$(BIN)/tone.wav: tools/make_tone.py | $(BIN)
	python3 $< $@

$(BIN):
	mkdir -p $(BIN)

clean:
	rm -rf $(BIN)

.PHONY: all clean
