MODULE DeepSets;
IMPORT Out, SYSTEM;

VAR
  ts: TINYSET;
  ss: SHORTSET;
  s: SET;
  ls: LONGSET;
  res: INTEGER;

PROCEDURE ConstPart;
BEGIN
  IF BITS(0) = {} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF BITS(5) = {0, 2} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF {1, 3} = BITS(10) THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END ConstPart;

PROCEDURE VarPart;
VAR i: INTEGER;
BEGIN
  ts := BITS(10);
  i := ORD(ts);
  ts := BITS(i);
  IF ORD(ts) = 10 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  ss := BITS(5);
  IF 2 IN ss THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END VarPart;

PROCEDURE OpsPart;
VAR a, b: SET;
BEGIN
  a := {1, 3, 5};
  b := {3, 7};
  IF 3 IN (a + b) THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF 1 IN (a * b) THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF 5 IN (a - b) THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  a := -a;
  IF 1 IN a THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END OpsPart;

PROCEDURE RangePart;
VAR r: SET;
BEGIN
  r := {4..7};
  IF 5 IN r THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF ~(3 IN r) THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END RangePart;

PROCEDURE LongPart;
BEGIN
  ls := BITS(0FFFFFFFFH);
  IF ORD(ls) = -1 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  s := BITS(0FFFFFFFFH);
  IF SYSTEM.VAL(SET, -1) = s THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END LongPart;

PROCEDURE ValPart;
VAR i: INTEGER; ti: TINYINT; b: BYTE; li: LONGINT;
BEGIN
  ss := BITS(100H);
  s := SYSTEM.VAL(SET, ss);
  IF 8 IN s THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  ts := {5};
  s := SYSTEM.VAL(SET, ts);
  IF (5 IN s) & ~(8 IN s) THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  s := BITS(0FFFFH);
  ss := SYSTEM.VAL(SHORTSET, s);
  IF 15 IN ss THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  i := ORD(ss);
  ts := SYSTEM.VAL(TINYSET, i);
  IF (4 IN ts) & ~(8 IN ts) THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  ti := -1;
  ls := SYSTEM.VAL(LONGSET, ti);
  IF ORD(ls) = -1 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  b := 0FEH;
  s := SYSTEM.VAL(SET, b);
  IF 6 IN s THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  ls := BITS(0FFFFFFFFH);
  i := SYSTEM.VAL(INTEGER, ls);
  IF i = -1 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  li := SYSTEM.VAL(LONGINT, ls);
  IF li = -1 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  ls := BITS(LONG(LONG(LONG(ti))));
  IF ORD(ls) = -1 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END ValPart;

BEGIN
  ConstPart;
  VarPart;
  OpsPart;
  RangePart;
  LongPart;
  ValPart
END DeepSets.
