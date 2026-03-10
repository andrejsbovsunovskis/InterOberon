
all: InterOberon

InterOberon: *.Mod
	fob InterOberon.Mod

run: all
	clear
	@./InterOberon Examples/Example.Mod && \
	echo ----------------- object file ----------------- && \
	hexutf Example.obj && \
	echo ----------------- executable ------------------ && \
	hexutf Example|head -n 518|tail -n 6 && \
	echo -------------------- RUN  --------------------- && \
	./Example && \
	./Example | hexdump -C

#@echo ----------------- symbol file ----------------- && \
#@hexutf Example.sym && \

clean:
	rm -rf _Build InterOberon

.PHONY: run clean
