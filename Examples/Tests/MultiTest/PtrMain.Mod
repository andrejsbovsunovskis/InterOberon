MODULE PtrMain;
IMPORT Out, PtrLib;

PROCEDURE Run*;
VAR head, p: PtrLib.Node;
  i, s: INTEGER;
BEGIN
  head := NIL;
  FOR i := 1 TO 4 DO
    head := PtrLib.Cons(i * i, head)
  END;

  Out.String('values:');
  p := head;
  WHILE p # NIL DO
    Out.Char(' '); Out.Int(p.v, 0);
    p := p.next
  END;
  Out.Ln;

  s := PtrLib.Sum(head);
  Out.String('sum='); Out.Int(s, 0); Out.Ln
END Run;

BEGIN
  Out.String('PtrMain initialized'); Out.Ln
END PtrMain.
