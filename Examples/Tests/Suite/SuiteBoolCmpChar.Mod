MODULE SuiteBoolCmpChar;
IMPORT Out;
CONST
  LetterA = 41H;
  Digit0 = 48;
  Five = 5;
  Limit = 100;

PROCEDURE BoolPart;
VAR a, b: BOOLEAN; i: INTEGER;
BEGIN
  a := TRUE;
  IF a THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := FALSE;
  IF a THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := TRUE;
  IF ~a THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := FALSE;
  IF ~a THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := TRUE; b := TRUE;
  IF a & b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := TRUE; b := FALSE;
  IF a & b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := FALSE; b := TRUE;
  IF a & b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := FALSE; b := FALSE;
  IF a & b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := TRUE; b := TRUE;
  IF a OR b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := TRUE; b := FALSE;
  IF a OR b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := FALSE; b := TRUE;
  IF a OR b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := FALSE; b := FALSE;
  IF a OR b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF 5 > 3 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF 2 > 3 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  Out.Int(ORD(TRUE), 0); Out.Ln;
  Out.Int(ORD(FALSE), 0); Out.Ln;
  i := 0;
  a := FALSE;
  IF a & (1 = 1) THEN i := 1 END;
  Out.Int(i, 0); Out.Ln;
  i := 0;
  a := TRUE;
  IF a OR (1 = 0) THEN i := 1 END;
  Out.Int(i, 0); Out.Ln;
  IF (TRUE & FALSE) OR TRUE THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF TRUE & (FALSE OR TRUE) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END BoolPart;

PROCEDURE CompPart;
VAR a, b: INTEGER;
BEGIN
  a := Five; b := Five;
  IF a = b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := 5; b := 3;
  IF a # b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := 3; b := 5;
  IF a < b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := 5; b := 5;
  IF a <= b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := 7; b := 3;
  IF a > b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := 5; b := 5;
  IF a >= b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := 5; b := 3;
  IF a < b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := -5; b := 0;
  IF a < b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := -10; b := 10;
  IF a < b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := -2; b := -5;
  IF a > b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF 0 = 0 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF 0 # 1 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := 2 * 3;
  b := 3 * 3;
  IF a < b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF 2 * 5 = 10 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  a := 50;
  IF (a > 0) & (a < Limit) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF Five = Five THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF Five < Limit THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END CompPart;

PROCEDURE CharPart;
VAR c: CHAR; i: INTEGER;
BEGIN
  c := CHR(LetterA);
  Out.Char(c); Out.Ln;
  c := 'Z';
  Out.Char(c); Out.Ln;
  c := 'A';
  Out.Int(ORD(c), 0); Out.Ln;
  c := '0';
  Out.Int(ORD(c), 0); Out.Ln;
  c := CHR(66);
  Out.Char(c); Out.Ln;
  i := ORD(CHR(90));
  Out.Int(i, 0); Out.Ln;
  IF 'B' > 'A' THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF 'X' = 'X' THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF 'X' # 'Y' THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  FOR i := 0 TO 9 DO
    Out.Char(CHR(Digit0 + i))
  END;
  Out.Ln;
  FOR i := 0 TO 5 DO
    Out.Char(CHR(97 + i))
  END;
  Out.Ln;
  c := 'M';
  IF (c >= 'A') & (c <= 'Z') THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  Out.Int(ORD(' '), 0); Out.Ln;
  i := 72;
  c := CHR(i);
  Out.Char(c); Out.Ln;
  c := 'A';
  c := CHR(ORD(c) + 1);
  Out.Char(c); Out.Ln;
  Out.Int(ORD("h"), 0); Out.Ln
END CharPart;

PROCEDURE IsHexDigit(x: BYTE): BOOLEAN;
BEGIN
RETURN ((x >= 30H) & (x <= 39H)) OR ((x >= 41H) & (x <= 46H)) OR ((x >= 61H) & (x <= 66H))
END IsHexDigit;

PROCEDURE HexRangePart;
VAR b: BYTE;
BEGIN
  b := 30H;
  IF IsHexDigit(b) THEN Out.String('0') ELSE Out.String('no') END; Out.Ln;
  b := 41H;
  IF IsHexDigit(b) THEN Out.String('A') ELSE Out.String('no') END; Out.Ln;
  b := 61H;
  IF IsHexDigit(b) THEN Out.String('a') ELSE Out.String('no') END; Out.Ln;
  b := 2FH;
  IF IsHexDigit(b) THEN Out.String('slash') ELSE Out.String('no') END; Out.Ln
END HexRangePart;

BEGIN
  BoolPart; CompPart; CharPart; HexRangePart
END SuiteBoolCmpChar.
