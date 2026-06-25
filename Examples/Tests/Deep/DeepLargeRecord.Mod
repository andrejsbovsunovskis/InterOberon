MODULE DeepLargeRecord;
IMPORT Out;

TYPE
  (* Cell has an 8-byte record tag, so every Padding value is larger than
     the 4095-byte ADD-immediate limit.  Fields after one or more Padding
     values exercise large record offsets. *)
  Cell = RECORD value: INTEGER END;
  Padding = RECORD cells: ARRAY 15, 30 OF Cell END;
  Pair = RECORD left, right: INTEGER END;
  Large = RECORD
    head: INTEGER;
    padding: Padding;
    middle: INTEGER;
    second: Padding;
    tail: Pair;
    last: INTEGER
  END;
  Holder = RECORD
    first: Large;
    gap: Padding;
    second: Large
  END;
  LargePtr = POINTER TO Large;
  HolderPtr = POINTER TO Holder;

VAR
  passed, failed, checksum: INTEGER;
  global: Large;

PROCEDURE Check(ok: BOOLEAN; value: INTEGER);
BEGIN
  IF ok THEN INC(passed) ELSE INC(failed) END;
  checksum := checksum + value
END Check;

PROCEDURE SetLarge(VAR x: Large; base: INTEGER);
BEGIN
  x.head := base;
  x.padding.cells[0, 0].value := base + 1;
  x.padding.cells[14, 29].value := base + 2;
  x.middle := base + 3;
  x.second.cells[7, 11].value := base + 4;
  x.second.cells[14, 29].value := base + 5;
  x.tail.left := base + 6;
  x.tail.right := base + 7;
  x.last := base + 8
END SetLarge;

PROCEDURE SumLarge(VAR x: Large): INTEGER;
BEGIN
RETURN x.head
  + x.padding.cells[0, 0].value
  + x.padding.cells[14, 29].value
  + x.middle
  + x.second.cells[7, 11].value
  + x.second.cells[14, 29].value
  + x.tail.left
  + x.tail.right
  + x.last
END SumLarge;

PROCEDURE BumpLarge(VAR x: Large; d: INTEGER);
BEGIN
  x.middle := x.middle + d;
  x.tail.left := x.tail.left + 2 * d;
  x.last := x.last + 3 * d
END BumpLarge;

PROCEDURE LocalPart;
VAR x: Large;
BEGIN
  SetLarge(x, 10);
  Check(SumLarge(x) = 126, SumLarge(x));
  BumpLarge(x, 4);
  Check(SumLarge(x) = 150, x.middle + x.tail.left + x.last);
  x.second.cells[14, 29].value := x.padding.cells[14, 29].value + x.tail.right;
  Check(x.second.cells[14, 29].value = 29, x.second.cells[14, 29].value)
END LocalPart;

PROCEDURE PointerPart;
VAR p: LargePtr;
BEGIN
  NEW(p);
  SetLarge(p^, 100);
  Check(SumLarge(p^) = 936, SumLarge(p^));
  p.middle := 777;
  p.tail.right := 33;
  p.last := p.middle + p.tail.right;
  Check((p.middle = 777) & (p.last = 810), p.last);
  p.second.cells[14, 29].value := p.last - p.padding.cells[14, 29].value;
  Check(p.second.cells[14, 29].value = 708, p.second.cells[14, 29].value)
END PointerPart;

PROCEDURE HolderPart;
VAR h: Holder; hp: HolderPtr;
BEGIN
  h.first.head := 1;
  h.first.last := 9;
  h.second.head := 20;
  h.second.middle := 23;
  h.second.tail.left := h.first.last + h.second.middle;
  h.second.tail.right := 27;
  h.second.last := 28;
  h.second.second.cells[14, 29].value := h.second.tail.left + h.second.last;
  Check(h.second.tail.left = 32, h.second.tail.left);
  Check(h.second.second.cells[14, 29].value = 60, h.second.second.cells[14, 29].value);

  NEW(hp);
  hp.second.middle := 33;
  hp.second.last := 38;
  hp.second.tail.left := hp.second.middle + hp.second.last;
  Check(hp.second.tail.left = 71, hp.second.tail.left);
  hp.second.second.cells[14, 29].value := hp.second.tail.left + 7;
  Check(hp.second.second.cells[14, 29].value = 78, hp.second.second.cells[14, 29].value)
END HolderPart;

PROCEDURE GlobalPart;
BEGIN
  SetLarge(global, 200);
  global.last := global.padding.cells[14, 29].value + global.second.cells[14, 29].value;
  Check(global.last = 407, global.last);
  Check(SumLarge(global) = 2035, SumLarge(global))
END GlobalPart;

BEGIN
  LocalPart;
  PointerPart;
  HolderPart;
  GlobalPart;
  Out.Int(passed, 0); Out.Ln;
  Out.Int(failed, 0); Out.Ln;
  Out.Int(checksum, 0); Out.Ln
END DeepLargeRecord.
