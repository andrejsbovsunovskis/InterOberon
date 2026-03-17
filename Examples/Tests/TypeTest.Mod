MODULE TypeTest;
IMPORT Out;
VAR
  si: SHORTINT;
  li: LONGINT;
  ls: LONGSET;
  i: INTEGER;
  s: SET;
BEGIN
  (* SHORTINT tests *)
  si := 100;
  Out.Int(si, 0); Out.Ln;

  si := -1;
  Out.Int(si, 0); Out.Ln;

  si := 200;
  si := si + 50;
  Out.Int(si, 0); Out.Ln;

  (* SHORTINT comparison *)
  si := -5;
  IF si < 0 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* LONGINT tests *)
  li := 1000000;
  Out.Int(li, 0); Out.Ln;

  li := -42;
  Out.Int(li, 0); Out.Ln;

  li := 999;
  li := li * 1000;
  Out.Int(li, 0); Out.Ln;

  (* LONGSET test *)
  ls := {};
  INCL(ls, 5);
  IF 5 IN ls THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* Cross-type assignment: INTEGER to SHORTINT *)
  i := 42;
  si := i;
  Out.Int(si, 0); Out.Ln;

  (* Cross-type assignment: INTEGER to LONGINT *)
  i := 777;
  li := i;
  Out.Int(li, 0); Out.Ln;

  (* Cross-type assignment: SET to LONGSET *)
  s := {1, 3, 5};
  ls := s;
  IF 3 IN ls THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END TypeTest.
