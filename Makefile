
all: InterOberon

InterOberon: *.Mod
	clear
	fob InterOberon.Mod

run: all
	./InterOberon Examples/Example.Mod
	#@echo ----------------- symbol file -----------------
	#@hexutf Example.sym
	@echo ----------------- object file -----------------
	@hexutf Example.obj
	@echo ----------------- executable ------------------
	@hexutf Example|head -n 40
	@echo "          ~~~"
	@hexutf Example|head -n 518|tail -n 6

clean:
	rm -rf _Build InterOberon

.PHONY: run clean
