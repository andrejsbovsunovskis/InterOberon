MODULE DeepRecords;
IMPORT Out;

TYPE
  Base = RECORD tag: INTEGER; val: INTEGER END;
  Ext = RECORD (Base) extra: INTEGER END;
  Node = POINTER TO NodeDesc;
  NodeDesc = RECORD v: INTEGER; next: Node END;

VAR res: INTEGER;

PROCEDURE ValuePart;
VAR b: Base; e: Ext;
BEGIN
  b.tag := 1; b.val := 10;
  Out.Int(b.val, 0); Out.Ln;
  e.tag := 2; e.val := 20; e.extra := 3;
  Out.Int(e.val + e.extra, 0); Out.Ln
END ValuePart;

PROCEDURE PtrPart;
VAR n, head: Node;
BEGIN
  head := NIL;
  NEW(n); n.v := 7; n.next := head; head := n;
  NEW(n); n.v := 3; n.next := head; head := n;
  IF (head # NIL) & (head.v = 3) THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  n := head.next;
  IF (n # NIL) & (n.v = 7) THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END PtrPart;

PROCEDURE AssignPart;
VAR a, b: Base;
BEGIN
  a.val := 5; a.tag := 1;
  b := a;
  a.val := 99;
  IF b.val = 5 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END AssignPart;

BEGIN
  ValuePart;
  PtrPart;
  AssignPart
END DeepRecords.
