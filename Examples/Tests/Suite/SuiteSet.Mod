MODULE SuiteSet;
IMPORT Out;
VAR s, t: SET; i, res: INTEGER;

PROCEDURE InclExclVarPart;
VAR g: SET;
  gls: LONGSET;
  li: LONGINT;

  PROCEDURE DoLocal;
  VAR loc: SET;
  BEGIN
    loc := {};
    INCL(loc, 3);
    Out.Int(ORD(loc), 0); Out.Ln;
    EXCL(loc, 3);
    Out.Int(ORD(loc), 0); Out.Ln
  END DoLocal;

  PROCEDURE Touch(VAR t: SET);
  BEGIN
    INCL(t, 5)
  END Touch;

  PROCEDURE TouchLong(VAR ls: LONGSET);
  BEGIN
    INCL(ls, 6)
  END TouchLong;

BEGIN
  DoLocal;
  g := {};
  Touch(g);
  Out.Int(ORD(g), 0); Out.Ln;
  gls := {};
  TouchLong(gls);
  li := ORD(gls);
  Out.Int(SHORT(li), 0); Out.Ln
END InclExclVarPart;

BEGIN
  (* SetTest *)
  s := {};
  Out.Int(ORD(s), 0); Out.Ln;
  s := {0};
  Out.Int(ORD(s), 0); Out.Ln;
  s := {3};
  Out.Int(ORD(s), 0); Out.Ln;
  s := {0, 1, 2};
  Out.Int(ORD(s), 0); Out.Ln;
  s := {0..3};
  Out.Int(ORD(s), 0); Out.Ln;
  s := {4..7};
  Out.Int(ORD(s), 0); Out.Ln;
  s := {0, 1} + {2, 3};
  Out.Int(ORD(s), 0); Out.Ln;
  s := {0, 1, 2} * {1, 2, 3};
  Out.Int(ORD(s), 0); Out.Ln;
  s := {0, 1, 2, 3} - {1, 3};
  Out.Int(ORD(s), 0); Out.Ln;
  s := {0, 1, 2} / {1, 2, 3};
  Out.Int(ORD(s), 0); Out.Ln;
  IF 2 IN {1, 2, 3} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF 5 IN {1, 2, 3} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  s := {};
  INCL(s, 3);
  Out.Int(ORD(s), 0); Out.Ln;
  s := {0..3};
  EXCL(s, 1);
  Out.Int(ORD(s), 0); Out.Ln;
  IF {1, 2} = {1, 2} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF {1, 2} # {1, 3} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  s := {0, 1}; t := {2, 3};
  s := s + t;
  Out.Int(ORD(s), 0); Out.Ln;
  s := {1, 2, 3}; t := {2, 3, 4};
  s := s * t;
  Out.Int(ORD(s), 0); Out.Ln;
  i := 2;
  IF i IN {0..4} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  s := {};
  INCL(s, 0);
  INCL(s, 2);
  INCL(s, 4);
  Out.Int(ORD(s), 0); Out.Ln;
  s := {0..7};
  EXCL(s, 0);
  EXCL(s, 7);
  Out.Int(ORD(s), 0); Out.Ln;
  s := {0..4}; t := {1, 3};
  s := s - t;
  Out.Int(ORD(s), 0); Out.Ln;
  s := {0, 1, 2}; t := {1, 2, 3};
  s := s / t;
  Out.Int(ORD(s), 0); Out.Ln;
  s := {1, 3, 5, 7};
  res := 0; i := 0;
  WHILE i < 10 DO
    IF i IN s THEN res := res + 1 END;
    i := i + 1
  END;
  Out.Int(res, 0); Out.Ln;

  (* SetAdv *)
  s := {0..31};
  t := -s;
  Out.Int(ORD(t), 0); Out.Ln;
  s := {};
  INCL(s, 0); INCL(s, 2); INCL(s, 4);
  Out.Int(ORD(s), 0); Out.Ln;
  EXCL(s, 2);
  Out.Int(ORD(s), 0); Out.Ln;
  i := 4;
  IF i IN s THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  i := 2;
  IF i IN s THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  s := {5..5};
  Out.Int(ORD(s), 0); Out.Ln;
  s := {0, 1} + {10, 11};
  Out.Int(ORD(s), 0); Out.Ln;
  s := {};
  FOR i := 0 TO 7 DO
    IF ODD(i) THEN INCL(s, i) END
  END;
  Out.Int(ORD(s), 0); Out.Ln;
  s := {2, 5, 7, 11, 13};
  res := 0;
  FOR i := 0 TO 31 DO
    IF i IN s THEN res := res + 1 END
  END;
  Out.Int(res, 0); Out.Ln;
  s := {1, 2, 3, 4};
  t := {3, 4, 5, 6};
  s := s / t;
  Out.Int(ORD(s), 0); Out.Ln;
  s := {1, 3, 5};
  s := s * s;
  Out.Int(ORD(s), 0); Out.Ln;
  s := {1, 3, 5};
  s := s - s;
  Out.Int(ORD(s), 0); Out.Ln;
  InclExclVarPart
END SuiteSet.
