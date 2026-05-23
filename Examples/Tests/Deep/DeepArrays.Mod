MODULE DeepArrays;
IMPORT Out;

VAR res: INTEGER;

PROCEDURE FixedPart;
VAR a: ARRAY 4 OF INTEGER; i, s: INTEGER;
BEGIN
  FOR i := 0 TO 3 DO a[i] := i + 1 END;
  s := 0;
  FOR i := 0 TO 3 DO s := s + a[i] END;
  Out.Int(s, 0); Out.Ln;
  a[2] := 99;
  Out.Int(a[2], 0); Out.Ln
END FixedPart;

PROCEDURE MdPart;
VAR m: ARRAY 2, 3 OF INTEGER; i, j, s: INTEGER;
BEGIN
  FOR i := 0 TO 1 DO
    FOR j := 0 TO 2 DO m[i, j] := i * 10 + j END
  END;
  s := m[0, 0] + m[1, 2];
  Out.Int(s, 0); Out.Ln;
  m[1, 1] := 77;
  Out.Int(m[1, 1], 0); Out.Ln
END MdPart;

PROCEDURE CharArrPart;
VAR s: ARRAY 8 OF CHAR; i: INTEGER;
BEGIN
  s[0] := 'D'; s[1] := 'e'; s[2] := 'e'; s[3] := 'p'; s[4] := 0X;
  i := 0;
  WHILE s[i] # 0X DO INC(i) END;
  Out.Int(i, 0); Out.Ln
END CharArrPart;

BEGIN
  FixedPart;
  MdPart;
  CharArrPart
END DeepArrays.
