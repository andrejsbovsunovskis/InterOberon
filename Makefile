
all: InterOberon

InterOberon: *.Mod
	clear
	fob InterOberon.Mod

run: all
	./InterOberon -c Examples/Example.Mod
	@hexutf Example.sym
	@echo ----------------- machine code -----------------
	@hexutf Example.o

clean:
	rm -rf _Build InterOberon

.PHONY: run clean
