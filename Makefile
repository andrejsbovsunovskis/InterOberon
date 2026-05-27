
FOBDIR ?= ../FreeOberon
FOB    := $(FOBDIR)/fob
SRCDIR := $(CURDIR)

all: InterOberon showdef

lib: InterOberon
	@./InterOberon --build-lib

InterOberon: *.Mod
	cd $(FOBDIR) && $(FOB) $(SRCDIR)/InterOberon.Mod
	mv $(FOBDIR)/InterOberon $(SRCDIR)/InterOberon

showdef: ShowDef.Mod InterOberon
	cd $(FOBDIR) && $(FOB) $(SRCDIR)/ShowDef.Mod
	mv $(FOBDIR)/ShowDef $(SRCDIR)/showdef

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
