
FOBDIR ?= ../FreeOberon
FOB    := $(FOBDIR)/fob
SRCDIR := $(CURDIR)

all: InterOberon showdef

lib: InterOberon
	@./InterOberon --build-lib

InterOberon: *.Mod
	$(FOB) -o $(SRCDIR)/InterOberon $(SRCDIR)/InterOberon.Mod

showdef: ShowDef.Mod InterOberon
	$(FOB) -o $(SRCDIR)/showdef $(SRCDIR)/ShowDef.Mod

run: all
	@clear
	@mkdir -p _Build
	@./InterOberon Examples/Example.Mod && \
	echo ----------------- object file ----------------- && \
	hexutf _Build/Example.obj|head -n 6 && \
	echo ----------------- executable ------------------ && \
	hexutf Example|head -n 518|tail -n 6 && \
	echo -------------------- RUN  --------------------- && \
	./Example && \
	./Example | hexdump -C

#@echo ----------------- symbol file ----------------- && \
#@hexutf Example.sym && \

clean:
	rm -rf _Build InterOberon showdef

.PHONY: run clean lib
