MODULE SuiteFlow;
IMPORT Out;
CONST MaxI = 5;

PROCEDURE IfPart;
VAR a, b, res: INTEGER;
BEGIN
  a := 5; res := 0;
  IF a > 3 THEN res := 1 END;
  Out.Int(res, 0); Out.Ln;
  a := 2; res := 0;
  IF a > 3 THEN res := 1 END;
  Out.Int(res, 0); Out.Ln;
  a := 10;
  IF a = 10 THEN res := 100 ELSE res := 200 END;
  Out.Int(res, 0); Out.Ln;
  a := 9;
  IF a = 10 THEN res := 100 ELSE res := 200 END;
  Out.Int(res, 0); Out.Ln;
  a := 1;
  IF a = 1 THEN res := 10
  ELSIF a = 2 THEN res := 20
  ELSIF a = 3 THEN res := 30
  END;
  Out.Int(res, 0); Out.Ln;
  a := 2;
  IF a = 1 THEN res := 10
  ELSIF a = 2 THEN res := 20
  ELSIF a = 3 THEN res := 30
  END;
  Out.Int(res, 0); Out.Ln;
  a := 3;
  IF a = 1 THEN res := 10
  ELSIF a = 2 THEN res := 20
  ELSIF a = 3 THEN res := 30
  END;
  Out.Int(res, 0); Out.Ln;
  a := 99;
  IF a = 1 THEN res := 10
  ELSIF a = 2 THEN res := 20
  ELSIF a = 3 THEN res := 30
  ELSE res := 99
  END;
  Out.Int(res, 0); Out.Ln;
  a := 5; b := 7; res := 0;
  IF a < 10 THEN
    IF b > 5 THEN res := 1 ELSE res := 2 END
  ELSE
    res := 3
  END;
  Out.Int(res, 0); Out.Ln;
  a := 15; b := 3; res := 0;
  IF a < 10 THEN
    res := 1
  ELSE
    IF b < 5 THEN res := 2 ELSE res := 3 END
  END;
  Out.Int(res, 0); Out.Ln;
  a := 4; b := 8; res := 0;
  IF (a > 2) & (b > 6) THEN res := 1 END;
  Out.Int(res, 0); Out.Ln;
  a := 4; b := 5; res := 0;
  IF (a > 2) & (b > 6) THEN res := 1 END;
  Out.Int(res, 0); Out.Ln;
  a := 1; b := 0; res := 0;
  IF (a > 0) OR (b > 0) THEN res := 1 END;
  Out.Int(res, 0); Out.Ln;
  a := 0; b := 1; res := 0;
  IF (a > 0) OR (b > 0) THEN res := 1 END;
  Out.Int(res, 0); Out.Ln;
  a := 0; b := 0; res := 0;
  IF (a > 0) OR (b > 0) THEN res := 1 END;
  Out.Int(res, 0); Out.Ln;
  a := 0; res := 0;
  WHILE a < 5 DO
    IF a MOD 2 = 0 THEN res := res + 1 END;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;
  b := 0; a := 1;
  WHILE a <= 5 DO
    IF a = 1 THEN b := b + 1
    ELSIF a = 2 THEN b := b + 2
    ELSIF a = 3 THEN b := b + 4
    ELSIF a = 4 THEN b := b + 8
    ELSE b := b + 16
    END;
    a := a + 1
  END;
  Out.Int(b, 0); Out.Ln;
  a := 0;
  IF a >= 0 THEN res := 1 ELSE res := 2 END;
  Out.Int(res, 0); Out.Ln;
  a := 5; res := 0;
  IF ~(a = 3) THEN res := 7 END;
  Out.Int(res, 0); Out.Ln;
  a := 50;
  IF a < 0 THEN res := -1
  ELSIF a = 0 THEN res := 0
  ELSIF a < 10 THEN res := 1
  ELSIF a < 100 THEN res := 2
  ELSE res := 3
  END;
  Out.Int(res, 0); Out.Ln;
  Out.Char('O'); Out.Char('K'); Out.Ln
END IfPart;

PROCEDURE ForPart;
VAR i, j, k, sum, n, m, p: INTEGER;
BEGIN
  FOR i := 0 TO MaxI DO
    Out.Int(i, 0); Out.Char(' ')
  END;
  Out.Ln;
  FOR i := 0 TO 10 BY 2 DO
    Out.Int(i, 0); Out.Char(' ')
  END;
  Out.Ln;
  FOR i := 5 TO 0 BY -1 DO
    Out.Int(i, 0); Out.Char(' ')
  END;
  Out.Ln;
  sum := 0;
  FOR i := 1 TO 100 DO
    sum := sum + i
  END;
  Out.Int(sum, 0); Out.Ln;
  n := 3;
  FOR i := 1 TO n DO
    Out.Int(i, 0); Out.Char(' ')
  END;
  Out.Ln;
  sum := 99;
  FOR i := 10 TO 5 DO
    sum := 0
  END;
  Out.Int(sum, 0); Out.Ln;
  FOR i := 7 TO 7 DO
    Out.Int(i, 0)
  END;
  Out.Ln;
  n := 3; m := 2;
  FOR i := 1 TO n DO
    FOR j := 1 TO m DO
      Out.Int(i * 10 + j, 0); Out.Char(' ')
    END
  END;
  Out.Ln;
  n := 2; m := 2; p := 2;
  sum := 0;
  FOR i := 1 TO n DO
    FOR j := 1 TO m DO
      FOR k := 1 TO p DO
        sum := sum + i * 100 + j * 10 + k
      END
    END
  END;
  Out.Int(sum, 0); Out.Ln;
  n := 3;
  FOR i := 1 TO n DO
    FOR j := 1 TO 2 DO
      Out.Int(i, 0)
    END
  END;
  Out.Ln;
  m := 3;
  FOR i := 1 TO 2 DO
    FOR j := 1 TO m DO
      Out.Int(j, 0)
    END
  END;
  Out.Ln
END ForPart;

PROCEDURE WhilePart;
VAR a, b, res: INTEGER;
BEGIN
  a := 1; res := 0;
  WHILE a <= 5 DO
    res := res + a;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;
  a := 1; res := 0;
  WHILE a <= 3 DO
    res := res + 1;
    a := a + 1
  ELSIF a <= 6 DO
    res := res + 10;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;
  a := 0; res := 0;
  WHILE a < 2 DO
    res := res + 1;
    a := a + 1
  ELSIF a < 4 DO
    res := res + 10;
    a := a + 1
  ELSIF a < 6 DO
    res := res + 100;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;
  a := 10; res := 0;
  WHILE a < 5 DO
    res := res + 1;
    a := a + 1
  ELSIF a < 15 DO
    res := res + a;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;
  a := 100; res := 99;
  WHILE a < 50 DO
    res := 0;
    a := a + 1
  ELSIF a < 80 DO
    res := 0;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;
  a := 1; res := 0;
  WHILE (a > 0) & (a < 3) DO
    res := res + 1;
    a := a + 1
  ELSIF (a >= 3) OR (a = 10) DO
    res := res + 100;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;
  a := 1; res := 0;
  WHILE a <= 2 DO
    b := 1;
    WHILE b <= a DO
      res := res + b;
      b := b + 1
    END;
    a := a + 1
  ELSIF a <= 4 DO
    res := res + 10;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;
  a := 0; res := 0;
  WHILE a < 5 DO
    IF a MOD 2 = 0 THEN res := res + 2
    ELSE res := res + 1
    END;
    a := a + 1
  ELSIF a < 8 DO
    res := res + 10;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;
  a := 1; b := 0; res := 0;
  WHILE a < 3 DO
    res := res + a;
    a := a + 1
  ELSIF (a < 4) & (b = 0) DO
    b := 1;
    a := 0
  END;
  Out.Int(res, 0); Out.Ln;
  a := 0; res := 0;
  WHILE a < 1 DO
    res := res + 1;
    a := a + 1
  ELSIF a < 2 DO
    res := res + 10;
    a := a + 1
  ELSIF a < 3 DO
    res := res + 100;
    a := a + 1
  ELSIF a < 4 DO
    res := res + 1000;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;
  a := 1; res := 0;
  WHILE ~(a > 5) DO
    res := res + 1;
    a := a + 1
  ELSIF ~(a > 8) DO
    res := res + 10;
    a := a + 1
  END;
  Out.Int(res, 0); Out.Ln;
  a := 0; res := 0;
  WHILE a = 0 DO
    res := 7;
    a := 1
  ELSIF a = 1 DO
    res := res + 3;
    a := 2
  END;
  Out.Int(res, 0); Out.Ln;
  Out.Char('O'); Out.Char('K'); Out.Ln
END WhilePart;

PROCEDURE NestLoopPart;
VAR i, j, sum: INTEGER;
BEGIN
  FOR i := 1 TO 3 DO
    FOR j := 1 TO 3 DO
      Out.Int(i * j, 0)
    END;
    Out.Ln
  END;
  sum := 0;
  FOR i := 1 TO 4 DO
    FOR j := 1 TO 4 DO
      sum := sum + i * j
    END
  END;
  Out.Int(sum, 0); Out.Ln;
  FOR i := 1 TO 5 DO
    FOR j := 1 TO i DO
      Out.Char('*')
    END;
    Out.Ln
  END;
  FOR i := 1 TO 3 DO
    j := i;
    WHILE j > 0 DO
      Out.Char('.');
      j := j - 1
    END;
    Out.Ln
  END;
  FOR i := 0 TO 20 BY 3 DO
    Out.Int(i, 0); Out.Char(' ')
  END;
  Out.Ln;
  FOR i := 3 TO 1 BY -1 DO
    j := i;
    REPEAT
      Out.Int(j, 0);
      j := j - 1
    UNTIL j = 0;
    Out.Char(' ')
  END;
  Out.Ln;
  sum := 0;
  FOR i := 1 TO 10 DO
    sum := sum + i * i
  END;
  Out.Int(sum, 0); Out.Ln;
  i := 1; j := 1;
  sum := 0;
  WHILE sum < 6 DO
    sum := sum + 1;
    j := i + j;
    i := j - i
  END;
  Out.Int(j, 0); Out.Ln
END NestLoopPart;

BEGIN
  IfPart; ForPart; WhilePart; NestLoopPart
END SuiteFlow.
