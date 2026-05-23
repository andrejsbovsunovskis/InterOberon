MODULE Heap;
IMPORT SYSTEM;

CONST
  sysMmap = 197;

  protRead   = 1;
  protWrite  = 2;
  mapPrivate = 2;
  mapAnon    = 4096;

  arenaSize = 16 * 1024 * 1024;
  align = 8;

VAR
  heapPos, heapEnd: SYSTEM.ADRINT;

PROCEDURE MapAnon(size: LONGINT): SYSTEM.ADRINT;
VAR r: LONGINT; p: SYSTEM.ADRINT;
BEGIN
  r := SYSTEM.SVC(sysMmap, 0, size, protRead + protWrite,
                  mapPrivate + mapAnon, -1, 0);
  IF r < 0 THEN p := 0 ELSE p := r END
RETURN p END MapAnon;

PROCEDURE Allocate*(size: LONGINT): SYSTEM.ADRINT;
VAR p: SYSTEM.ADRINT;
  asize: LONGINT;
BEGIN
  IF size <= 0 THEN size := align END;
  asize := (size + align - 1) DIV align * align;
  IF asize > arenaSize DIV 2 THEN
    p := MapAnon(asize)
  ELSE
    IF heapPos + asize > heapEnd THEN
      heapPos := MapAnon(arenaSize);
      IF heapPos = 0 THEN heapEnd := 0
      ELSE heapEnd := heapPos + arenaSize
      END
    END;
    IF heapPos = 0 THEN p := 0
    ELSE
      p := heapPos;
      heapPos := heapPos + asize
    END
  END
RETURN p END Allocate;

BEGIN
  heapPos := 0; heapEnd := 0
END Heap.
