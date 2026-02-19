
all: InterOberon

InterOberon: *.Mod
	clear
	fob InterOberon.Mod

run: all
	./InterOberon -c Examples/Тест.Mod
	hexutf Тест.sym

clean:
	rm -rf _Build InterOberon

.PHONY: run clean
