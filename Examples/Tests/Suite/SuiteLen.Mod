MODULE SuiteLen;
(* LEN designator, string LEN/index, nested LEN in index. *)
IMPORT Out;

CONST
  msg = 'hello';
  str = 'hello';

TYPE
  Cell = RECORD ar: ARRAY 2, 3, 4 OF INTEGER END;
  RCell = RECORD x: ARRAY 5 OF Cell END;
  RMat = RECORD m: ARRAY 10, 20 OF INTEGER END;
  Mat = RECORD m: ARRAY 10, 20 OF INTEGER END;
  PMat = POINTER TO Mat;

VAR
  r: RCell;
  rm: RMat;
  p: PMat;
  c: CHAR;
  i: INTEGER;

PROCEDURE StringLen;
BEGIN
  Out.Int(LEN('hello'), 0); Out.Ln;
  Out.Int(LEN(msg), 0); Out.Ln
END StringLen;

PROCEDURE StringIndex;
BEGIN
  c := str[1]; Out.Char(c); Out.Ln;
  c := str[5]; Out.Int(ORD(c), 0); Out.Ln;
  i := 1; c := str[i]; Out.Char(c); Out.Ln
END StringIndex;

PROCEDURE RecordLen;
BEGIN
  Out.Int(LEN(r.x[1].ar), 0); Out.Ln;
  Out.Int(LEN(r.x[1].ar[0, 0]), 0); Out.Ln
END RecordLen;

PROCEDURE NestedLenIndex;
BEGIN
  Out.Int(LEN(rm.m[LEN(rm.m[0]) - 1]), 0); Out.Ln
END NestedLenIndex;

PROCEDURE PointerLen;
BEGIN
  NEW(p);
  Out.Int(LEN(p^.m[0]), 0); Out.Ln
END PointerLen;

BEGIN
  StringLen;
  StringIndex;
  RecordLen;
  NestedLenIndex;
  PointerLen
END SuiteLen.
