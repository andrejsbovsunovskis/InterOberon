MODULE SuiteNum;
IMPORT Out;
CONST
  Seven = 7;
  Hundred = 100;
  MaxArr = 20;
VAR
  arithA, arithB, arithR: INTEGER;
  fmtI: INTEGER;
  algoArr: ARRAY MaxArr OF INTEGER;
  algoI, algoJ, algoN, algoTmp: INTEGER;

PROCEDURE EdgePart;
VAR i, j: INTEGER; a: ARRAY 5 OF INTEGER; s: SET;
BEGIN
  i := 2147483647;
  Out.Int(i, 0); Out.Ln;
  i := -2147483647;
  i := i - 1;
  Out.Int(i, 0); Out.Ln;
  i := 0 DIV 7;
  Out.Int(i, 0); Out.Ln;
  i := 0 MOD 7;
  Out.Int(i, 0); Out.Ln;
  j := 0;
  FOR i := 1 TO 0 DO
    j := 1
  END;
  Out.Int(j, 0); Out.Ln;
  a[3] := 777;
  Out.Int(a[3], 0); Out.Ln;
  s := {};
  s := s + {};
  Out.Int(ORD(s), 0); Out.Ln;
  s := {0..31};
  IF 0 IN s THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  s := {};
  INCL(s, 31);
  IF 31 IN s THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  i := 10; j := 0;
  WHILE i < 5 DO
    j := 1;
    i := i + 1
  END;
  Out.Int(j, 0); Out.Ln;
  i := 100; j := 0;
  REPEAT
    j := j + 1;
    i := i - 1
  UNTIL i <= 99;
  Out.Int(j, 0); Out.Ln;
  i := 99;
  IF i = 1 THEN j := 1
  ELSIF i = 2 THEN j := 2
  ELSIF i = 3 THEN j := 3
  ELSE j := -1
  END;
  Out.Int(j, 0); Out.Ln;
  i := 42;
  i := i * (-1);
  Out.Int(i, 0); Out.Ln;
  i := -(-55);
  Out.Int(i, 0); Out.Ln;
  a[4] := 999;
  Out.Int(a[4], 0); Out.Ln
END EdgePart;

BEGIN
  (* ArithTest *)
  arithR := 3 + Seven;
  Out.Int(arithR, 0); Out.Ln;
  arithR := 20 - 13;
  Out.Int(arithR, 0); Out.Ln;
  arithR := 6 * 7;
  Out.Int(arithR, 0); Out.Ln;
  arithR := 17 DIV (Seven - 2);
  Out.Int(arithR, 0); Out.Ln;
  arithR := 17 MOD (Seven - 2);
  Out.Int(arithR, 0); Out.Ln;
  arithR := -42;
  Out.Int(arithR, 0); Out.Ln;
  arithA := -5;
  arithR := -arithA;
  Out.Int(arithR, 0); Out.Ln;
  arithR := 2 + 3 * 4;
  Out.Int(arithR, 0); Out.Ln;
  arithR := (2 + 3) * 4;
  Out.Int(arithR, 0); Out.Ln;
  arithR := 1000 * 1000;
  Out.Int(arithR, 0); Out.Ln;
  arithR := 1000000 DIV 7;
  Out.Int(arithR, 0); Out.Ln;
  arithR := 1000 MOD 7;
  Out.Int(arithR, 0); Out.Ln;
  arithR := 0 * 999;
  Out.Int(arithR, 0); Out.Ln;
  arithA := 77;
  arithR := arithA + 0;
  Out.Int(arithR, 0); Out.Ln;
  arithR := ((10 - 3) * 2 + 1) DIV 3;
  Out.Int(arithR, 0); Out.Ln;
  arithR := Hundred * Hundred;
  Out.Int(arithR, 0); Out.Ln;
  arithR := ABS(42);
  Out.Int(arithR, 0); Out.Ln;
  arithR := ABS(-99);
  Out.Int(arithR, 0); Out.Ln;
  arithR := ABS(0);
  Out.Int(arithR, 0); Out.Ln;
  arithA := 7;
  IF ODD(arithA) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  arithA := 8;
  IF ODD(arithA) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  arithA := 10;
  INC(arithA);
  Out.Int(arithA, 0); Out.Ln;
  arithA := 10;
  INC(arithA, 5);
  Out.Int(arithA, 0); Out.Ln;
  arithA := 10;
  DEC(arithA);
  Out.Int(arithA, 0); Out.Ln;
  arithA := 10;
  DEC(arithA, 3);
  Out.Int(arithA, 0); Out.Ln;
  arithA := 3; arithB := 4;
  arithR := arithA * arithA + arithB * arithB;
  Out.Int(arithR, 0); Out.Ln;

  EdgePart;

  (* OutFmt *)
  Out.Int(42, 0); Out.Ln;
  Out.Int(-7, 0); Out.Ln;
  Out.Int(0, 0); Out.Ln;
  Out.Int(123456, 0); Out.Ln;
  Out.Char('[');
  Out.Int(99, 0);
  Out.Char(']');
  Out.Ln;
  FOR fmtI := 0 TO 19 DO
    Out.Char('-')
  END;
  Out.Ln;
  FOR fmtI := 1 TO 5 DO
    Out.Int(fmtI, 0);
    Out.Char(':');
    Out.Int(fmtI * fmtI, 0);
    Out.Ln
  END;
  FOR fmtI := 0 TO 9 DO
    Out.Char(CHR(65 + fmtI))
  END;
  Out.Ln;
  Out.Char('(');
  Out.Int(1, 0);
  Out.Char('+');
  Out.Int(2, 0);
  Out.Char('=');
  Out.Int(3, 0);
  Out.Char(')');
  Out.Ln;
  Out.Int(111, 0); Out.Ln;
  Out.Int(222, 0); Out.Ln;
  Out.Int(333, 0); Out.Ln;

  (* Algo *)
  algoI := 48; algoJ := 18;
  WHILE algoJ # 0 DO
    algoTmp := algoJ;
    algoJ := algoI MOD algoJ;
    algoI := algoTmp
  END;
  Out.Int(algoI, 0); Out.Ln;
  algoN := 1;
  FOR algoI := 1 TO 10 DO
    algoN := algoN * algoI
  END;
  Out.Int(algoN, 0); Out.Ln;
  algoI := 1; algoJ := 1;
  Out.Int(algoI, 0); Out.Char(' ');
  Out.Int(algoJ, 0); Out.Char(' ');
  algoN := 0;
  WHILE algoN < 6 DO
    algoTmp := algoI + algoJ;
    algoI := algoJ;
    algoJ := algoTmp;
    Out.Int(algoJ, 0); Out.Char(' ');
    algoN := algoN + 1
  END;
  Out.Ln;
  algoN := 1;
  FOR algoI := 1 TO 10 DO
    algoN := algoN * 2
  END;
  Out.Int(algoN, 0); Out.Ln;
  algoI := 12345;
  algoN := 0;
  WHILE algoI > 0 DO
    algoN := algoN + algoI MOD 10;
    algoI := algoI DIV 10
  END;
  Out.Int(algoN, 0); Out.Ln;
  algoI := 1234;
  WHILE algoI > 0 DO
    Out.Int(algoI MOD 10, 0);
    algoI := algoI DIV 10
  END;
  Out.Ln;
  algoN := 0;
  FOR algoI := 2 TO 30 DO
    algoJ := 2;
    algoTmp := 1;
    WHILE algoJ * algoJ <= algoI DO
      IF algoI MOD algoJ = 0 THEN algoTmp := 0 END;
      algoJ := algoJ + 1
    END;
    IF algoTmp = 1 THEN algoN := algoN + 1 END
  END;
  Out.Int(algoN, 0); Out.Ln;
  algoI := 42; algoN := 0;
  WHILE algoI > 0 DO
    IF ODD(algoI) THEN algoN := algoN + 1 END;
    algoI := algoI DIV 2
  END;
  Out.Int(algoN, 0); Out.Ln;
  algoArr[0] := 9; algoArr[1] := 7; algoArr[2] := 5; algoArr[3] := 3; algoArr[4] := 1;
  FOR algoI := 0 TO 3 DO
    algoN := algoI;
    FOR algoJ := algoI + 1 TO 4 DO
      IF algoArr[algoJ] < algoArr[algoN] THEN algoN := algoJ END
    END;
    IF algoN # algoI THEN
      algoTmp := algoArr[algoI]; algoArr[algoI] := algoArr[algoN]; algoArr[algoN] := algoTmp
    END
  END;
  FOR algoI := 0 TO 4 DO
    Out.Int(algoArr[algoI], 0); Out.Char(' ')
  END;
  Out.Ln;
  algoI := 27; algoN := 0;
  WHILE algoI # 1 DO
    IF ODD(algoI) THEN
      algoI := 3 * algoI + 1
    ELSE
      algoI := algoI DIV 2
    END;
    algoN := algoN + 1
  END;
  Out.Int(algoN, 0); Out.Ln
END SuiteNum.
