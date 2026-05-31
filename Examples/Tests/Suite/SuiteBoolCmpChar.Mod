MODULE SuiteBoolCmpChar;
IMPORT Out;
CONST
  LetterA = 41H;
  Digit0 = 48;
  Five = 5;
  Limit = 100;

TYPE
  BoolBox = RECORD
    a, b: BOOLEAN;
    n: INTEGER
  END;

VAR
  hits: INTEGER;

PROCEDURE PrintBool(b: BOOLEAN);
BEGIN
  Out.Int(ORD(b), 0); Out.Ln
END PrintBool;

PROCEDURE Probe(value: BOOLEAN): BOOLEAN;
BEGIN
  INC(hits)
RETURN value END Probe;

PROCEDURE ComplexReturn(a, b, c, d: BOOLEAN): BOOLEAN;
BEGIN
RETURN (a & (b OR c)) OR (~d & (a OR b))
END ComplexReturn;

PROCEDURE RelReturn(i, j: INTEGER; ch: CHAR): BOOLEAN;
BEGIN
RETURN ((i < j) & ((j - i) = 4)) OR ((('А' <= ch) & (ch <= 'Я')) OR (ch = 'Ё'))
END RelReturn;

PROCEDURE BoolPart;
VAR a, b: BOOLEAN; i: INTEGER; c: CHAR;
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
  Out.Ln;
  c := '?';
  IF (('А' <= c) & (c <= 'Я')) OR (c = 'Ё') THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  b := (('А' <= c) & (c <= 'Я')) OR (c = 'Ё');
  IF b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  c := 'Я';
  IF (('А' <= c) & (c <= 'Я')) OR (c = 'Ё') THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END BoolPart;

PROCEDURE BoolExprPart;
VAR a, b, c, d, res: BOOLEAN;
    i, j: INTEGER;
    ch: CHAR;
BEGIN
  PrintBool(TRUE OR FALSE);
  PrintBool(FALSE OR FALSE);
  PrintBool(TRUE & FALSE);
  PrintBool(TRUE & TRUE);
  PrintBool(TRUE OR FALSE & FALSE);
  PrintBool((TRUE OR FALSE) & FALSE);
  PrintBool(FALSE & TRUE OR TRUE);
  PrintBool(FALSE & (TRUE OR TRUE));
  PrintBool(((TRUE)));
  PrintBool((((FALSE OR FALSE))));

  a := TRUE; b := FALSE; c := TRUE; d := FALSE;
  PrintBool(a OR b);
  PrintBool(b OR d);
  PrintBool(a & c);
  PrintBool(a & b);
  PrintBool(a & b OR c);
  PrintBool(a & (b OR c));
  PrintBool((a OR b) & d);
  PrintBool(a OR b & d);
  PrintBool((b OR d) & a);
  PrintBool(b OR d & a);

  i := 3; j := 7;
  PrintBool((i < j) & (j = 7));
  PrintBool((i > j) OR (j = 7));
  PrintBool(((i + 4) = j) & ((j - i) = 4));
  PrintBool(((i * j) = 21) OR ((j MOD i) = 0));
  PrintBool(((i = 0) & (j = 7)) OR ((j DIV i) = 2));
  PrintBool(((i + j) < 5) OR ((j - i) = 4) & (j # i));

  PrintBool((a & c) OR (b & d));
  PrintBool((a OR b) & (c OR d));
  PrintBool((b OR d) OR (a & c));
  PrintBool((b & d) OR (a & c));
  PrintBool((b & (d OR a)) OR (d & a));
  PrintBool(a OR (b & (c OR d)));
  PrintBool(((b OR d) & (a OR c)) OR (d = a));
  PrintBool(b OR (d OR (a OR c)));
  PrintBool((((a))) & (((c OR d))) OR ((b)));

  ch := '?';
  PrintBool((('А' <= ch) & (ch <= 'Я')) OR (ch = 'Ё'));
  res := (('А' <= ch) & (ch <= 'Я')) OR (ch = 'Ё');
  PrintBool(res);
  ch := 'Ж';
  PrintBool((('А' <= ch) & (ch <= 'Я')) OR (ch = 'Ё'));
  res := (('А' <= ch) & (ch <= 'Я')) OR (ch = 'Ё');
  PrintBool(res);
  ch := 'Ё';
  PrintBool((('А' <= ch) & (ch <= 'Я')) OR (ch = 'Ё'));
  res := (('А' <= ch) & (ch <= 'Я')) OR (ch = 'Ё');
  PrintBool(res);
  ch := 'a';
  PrintBool((('А' <= ch) & (ch <= 'Я')) OR (ch = 'Ё'));

  hits := 0;
  IF TRUE OR Probe(FALSE) THEN END;
  Out.Int(hits, 0); Out.Ln;
  hits := 0;
  IF FALSE OR Probe(TRUE) THEN END;
  Out.Int(hits, 0); Out.Ln;
  hits := 0;
  IF FALSE & Probe(TRUE) THEN END;
  Out.Int(hits, 0); Out.Ln;
  hits := 0;
  IF TRUE & Probe(FALSE) THEN END;
  Out.Int(hits, 0); Out.Ln;
  hits := 0;
  IF (Probe(FALSE) & Probe(TRUE)) OR Probe(TRUE) THEN END;
  Out.Int(hits, 0); Out.Ln;
  hits := 0;
  IF Probe(TRUE) OR (Probe(FALSE) & Probe(TRUE)) THEN END;
  Out.Int(hits, 0); Out.Ln;
  hits := 0;
  res := Probe(TRUE) OR Probe(FALSE);
  Out.Int(hits, 0); Out.Char(':'); PrintBool(res);
  hits := 0;
  res := Probe(FALSE) & Probe(TRUE);
  Out.Int(hits, 0); Out.Char(':'); PrintBool(res)
END BoolExprPart;

PROCEDURE BoolControlPart;
VAR a, b, c, d, res: BOOLEAN;
    i, j, count, branch: INTEGER;
    ch: CHAR;
    arr: ARRAY 4 OF BOOLEAN;
    box: BoolBox;
BEGIN
  a := TRUE; b := FALSE; c := TRUE; d := FALSE;
  PrintBool(~a OR c);
  PrintBool(~(a & b));
  PrintBool(~(a OR c));
  PrintBool((~b & a) OR (d & c));
  PrintBool(~((a OR b) & (c OR d)) OR (b = d));
  PrintBool((~(b OR d) & (a OR c)) OR ~(a & c));
  PrintBool(~~a);
  PrintBool(~~~a);

  PrintBool(a OR b OR c OR d);
  PrintBool(b OR d OR FALSE OR a);
  PrintBool(a & c & TRUE & ~b);
  PrintBool(a & c & d & TRUE);
  PrintBool((a OR b OR d) & (c OR d OR b));
  PrintBool((b & d & a) OR (c & a & ~d));
  PrintBool((b OR d) OR (FALSE OR (a & c)) OR FALSE);
  PrintBool((a & c) & ((b OR d) OR TRUE) & ~(b & d));

  arr[0] := a & c;
  arr[1] := b OR d;
  arr[2] := (arr[0] OR arr[1]) & ~d;
  arr[3] := (arr[1] OR d) & a;
  PrintBool(arr[0]);
  PrintBool(arr[1]);
  PrintBool(arr[2]);
  PrintBool(arr[3]);

  box.a := arr[0] OR arr[1];
  box.b := (arr[2] & ~arr[3]) OR (b = d);
  box.n := 0;
  IF box.a & ~box.b THEN box.n := 1
  ELSIF box.a OR box.b THEN box.n := 2
  ELSE box.n := 3
  END;
  Out.Int(box.n, 0); Out.Ln;
  PrintBool(box.a);
  PrintBool(box.b);

  i := 0; count := 0;
  WHILE (i < 6) & ((i MOD 2 = 0) OR (count < 2)) DO
    INC(count);
    INC(i)
  END;
  Out.Int(i, 0); Out.Char(':'); Out.Int(count, 0); Out.Ln;

  i := 0; count := 0;
  WHILE (i < 2) & Probe(TRUE) DO
    INC(count);
    INC(i)
  ELSIF (i = 2) OR Probe(FALSE) DO
    count := count + 10;
    INC(i)
  END;
  Out.Int(i, 0); Out.Char(':'); Out.Int(count, 0); Out.Char(':'); Out.Int(hits, 0); Out.Ln;

  branch := 0; ch := '?'; i := 3; j := 7;
  IF ((i > j) & Probe(TRUE)) OR (ch = 'Ё') THEN
    branch := 1
  ELSIF ((i < j) & (j = 7)) OR ((('А' <= ch) & (ch <= 'Я')) OR (ch = 'Ё')) THEN
    branch := 2
  ELSIF Probe(TRUE) OR (a & c) THEN
    branch := 3
  ELSE
    branch := 4
  END;
  Out.Int(branch, 0); Out.Ln;

  branch := 0; ch := 'Ё';
  IF ((i > j) & Probe(TRUE)) OR (ch = 'Ё') THEN
    branch := 1
  ELSIF Probe(TRUE) THEN
    branch := 2
  ELSE
    branch := 3
  END;
  Out.Int(branch, 0); Out.Ln;

  PrintBool(ComplexReturn(a, b, c, d));
  PrintBool(ComplexReturn(b, d, b, a));
  PrintBool(RelReturn(3, 7, '?'));
  PrintBool(RelReturn(8, 9, 'Ж'));
  PrintBool(RelReturn(8, 9, 'x'));

  hits := 0;
  res := (Probe(FALSE) OR Probe(FALSE) OR Probe(TRUE)) & Probe(TRUE);
  Out.Int(hits, 0); Out.Char(':'); PrintBool(res);
  hits := 0;
  res := Probe(TRUE) & (Probe(FALSE) OR Probe(TRUE)) & Probe(TRUE);
  Out.Int(hits, 0); Out.Char(':'); PrintBool(res);
  hits := 0;
  res := Probe(FALSE) & (Probe(TRUE) OR Probe(TRUE)) OR Probe(FALSE);
  Out.Int(hits, 0); Out.Char(':'); PrintBool(res);
  hits := 0;
  IF Probe(TRUE) OR Probe(TRUE) OR Probe(TRUE) THEN END;
  Out.Int(hits, 0); Out.Ln;
  hits := 0;
  IF Probe(FALSE) & Probe(TRUE) & Probe(TRUE) THEN END;
  Out.Int(hits, 0); Out.Ln
END BoolControlPart;

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
  BoolPart; BoolExprPart; BoolControlPart; CompPart; CharPart; HexRangePart
END SuiteBoolCmpChar.
