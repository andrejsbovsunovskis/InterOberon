MODULE SuiteReal;
IMPORT Out;

PROCEDURE RealBasic;
VAR r, s: REAL; i: INTEGER;
BEGIN
  r := FLT(7);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := FLT(3) + FLT(4);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := FLT(10) - FLT(3);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := FLT(6) * FLT(5);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := FLT(20) / FLT(4);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := FLT(7) / FLT(2);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := -FLT(5) + FLT(12);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := 3.14;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := 100.5;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := 2.5 * 4.0;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  IF FLT(3) > FLT(2) THEN i := 1 ELSE i := 0 END;
  Out.Int(i, 0); Out.Ln;
  IF FLT(2) < FLT(5) THEN i := 1 ELSE i := 0 END;
  Out.Int(i, 0); Out.Ln;
  IF FLT(4) = FLT(4) THEN i := 1 ELSE i := 0 END;
  Out.Int(i, 0); Out.Ln;
  IF FLT(4) # FLT(5) THEN i := 1 ELSE i := 0 END;
  Out.Int(i, 0); Out.Ln;
  r := FLT(10); s := FLT(3);
  r := r / s;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := FLT(7) / FLT(2);
  r := r - FLT(FLOOR(r));
  r := r * FLT(10);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := 0.5 * 6.0;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := 1.5; s := 2.5;
  IF r < s THEN i := 1 ELSE i := 0 END;
  Out.Int(i, 0); Out.Ln;
  r := FLT(1000) * FLT(1000);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := 0.0;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln
END RealBasic;

PROCEDURE RealAdvPart;
VAR r, s: REAL; i: INTEGER;
BEGIN
  r := 0.0;
  FOR i := 1 TO 10 DO
    r := r + 0.1
  END;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := 1.5 * 2.0;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := 22.0 / 7.0;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := -2.5;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := 1.5; s := 2.5;
  IF r < s THEN Out.Int(1, 0) END;
  IF r <= s THEN Out.Int(1, 0) END;
  IF s > r THEN Out.Int(1, 0) END;
  IF s >= r THEN Out.Int(1, 0) END;
  IF r # s THEN Out.Int(1, 0) END;
  Out.Ln;
  r := 3.0;
  s := FLT(3);
  IF r = s THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  r := 1.0;
  FOR i := 1 TO 8 DO
    r := r * 2.0
  END;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  i := FLOOR(FLT(100) / FLT(3));
  Out.Int(i, 0); Out.Ln;
  r := 10.7 - 3.2;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;
  r := 1000000.0;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln
END RealAdvPart;

BEGIN
  RealBasic; RealAdvPart
END SuiteReal.
