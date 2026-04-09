MODULE CharTest;
IMPORT Out;
CONST
  LetterA = 41H;
  Digit0 = 48;
VAR c: CHAR; i: INTEGER;
BEGIN
  (* 1. Char literal 'A' *)
  c := CHR(LetterA);
  Out.Char(c); Out.Ln;

  (* 2. Char literal 'Z' *)
  c := 'Z';
  Out.Char(c); Out.Ln;

  (* 3. ORD of 'A' = 65 *)
  c := 'A';
  Out.Int(ORD(c), 0); Out.Ln;

  (* 4. ORD of '0' = 48 *)
  c := '0';
  Out.Int(ORD(c), 0); Out.Ln;

  (* 5. CHR: CHR(66) = 'B' *)
  c := CHR(66);
  Out.Char(c); Out.Ln;

  (* 6. CHR and ORD roundtrip: ORD(CHR(90)) = 90 *)
  i := ORD(CHR(90));
  Out.Int(i, 0); Out.Ln;

  (* 7. Char comparison: 'B' > 'A' → 1 *)
  IF 'B' > 'A' THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 8. Char equality: 'X' = 'X' → 1 *)
  IF 'X' = 'X' THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 9. Char inequality: 'X' # 'Y' → 1 *)
  IF 'X' # 'Y' THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 10. Print digits using CHR and Digit0 const *)
  FOR i := 0 TO 9 DO
    Out.Char(CHR(Digit0 + i))
  END;
  Out.Ln;

  (* 11. Print lowercase a-f *)
  FOR i := 0 TO 5 DO
    Out.Char(CHR(97 + i))
  END;
  Out.Ln;

  (* 12. Char variable comparison *)
  c := 'M';
  IF (c >= 'A') & (c <= 'Z') THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 13. Space character: ORD(' ') = 32 *)
  Out.Int(ORD(' '), 0); Out.Ln;

  (* 14. Char assignment from variable *)
  i := 72;
  c := CHR(i);
  Out.Char(c); Out.Ln;

  (* 15. Char INC: 'A' → 'B' *)
  c := 'A';
  c := CHR(ORD(c) + 1);
  Out.Char(c); Out.Ln
END CharTest.
