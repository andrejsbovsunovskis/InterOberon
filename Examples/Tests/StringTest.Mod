MODULE StringTest;
IMPORT Out;
CONST
  greet = 'Hello';
  empty = '';
  one = 'Z';
  hex = 41X;
VAR
  s: ARRAY 6 OF CHAR;
  s5: ARRAY 5 OF CHAR;
  s2: ARRAY 6 OF CHAR;
  a4: ARRAY 4 OF CHAR;
  b4: ARRAY 4 OF CHAR;
  ch: CHAR;
  ok: INTEGER;
BEGIN
  (* 1. Assign literal to ARRAY OF CHAR, Out.String *)
  s := 'Hello';
  Out.String(s); Out.Ln;

  (* 2. Assign string CONST to ARRAY OF CHAR *)
  s := greet;
  Out.String(s); Out.Ln;

  (* 3. 41X as CHAR assignment *)
  ch := 41X;
  Out.Char(ch); Out.Ln;

  (* 4. 41X as single-char string assigned to ARRAY *)
  s5 := 41X;
  Out.Char(s5[0]); Out.Ln;

  (* 5. Empty string CONST: s = '' checks first byte is 0X *)
  s := greet;
  IF s = '' THEN ok := 0 ELSE ok := 1 END;
  Out.Int(ok, 0); Out.Ln;

  (* 6. Assign empty literal, then check *)
  s := '';
  IF s = '' THEN ok := 1 ELSE ok := 0 END;
  Out.Int(ok, 0); Out.Ln;

  (* 7. Literal < literal: 'aa' < 'ab' = TRUE *)
  IF 'aa' < 'ab' THEN ok := 1 ELSE ok := 0 END;
  Out.Int(ok, 0); Out.Ln;

  (* 8. Literal = literal: 'Hi' = 'Hi' = TRUE *)
  IF 'Hi' = 'Hi' THEN ok := 1 ELSE ok := 0 END;
  Out.Int(ok, 0); Out.Ln;

  (* 9. Literal # literal: 'Hi' # 'Ho' = TRUE *)
  IF 'Hi' # 'Ho' THEN ok := 1 ELSE ok := 0 END;
  Out.Int(ok, 0); Out.Ln;

  (* 10. Variable = literal *)
  s := 'Hello';
  IF s = 'Hello' THEN ok := 1 ELSE ok := 0 END;
  Out.Int(ok, 0); Out.Ln;

  (* 11. Variable # literal *)
  IF s # 'World' THEN ok := 1 ELSE ok := 0 END;
  Out.Int(ok, 0); Out.Ln;

  (* 12. Variable < literal: 'Hello' < 'Hi' = TRUE (lexicographic) *)
  IF s < 'Hi' THEN ok := 1 ELSE ok := 0 END;
  Out.Int(ok, 0); Out.Ln;

  (* 13. Variable > literal: 'Hello' > 'He' = TRUE *)
  IF s > 'He' THEN ok := 1 ELSE ok := 0 END;
  Out.Int(ok, 0); Out.Ln;

  (* 14. Variable <= literal: 'Hello' <= 'Hello' = TRUE *)
  IF s <= 'Hello' THEN ok := 1 ELSE ok := 0 END;
  Out.Int(ok, 0); Out.Ln;

  (* 15. Variable >= literal: 'Hello' >= 'Hello' = TRUE *)
  IF s >= 'Hello' THEN ok := 1 ELSE ok := 0 END;
  Out.Int(ok, 0); Out.Ln;

  (* 16. Variable vs variable same content *)
  s2 := 'Hello';
  IF s = s2 THEN ok := 1 ELSE ok := 0 END;
  Out.Int(ok, 0); Out.Ln;

  (* 17. Variable vs variable different content *)
  s2 := 'World';
  IF s < s2 THEN ok := 1 ELSE ok := 0 END;
  Out.Int(ok, 0); Out.Ln;

  (* 18. NUL-terminated arrays: 'ABC' < 'ABD' in ARRAY 4 *)
  a4 := 'ABC';
  b4 := 'ABD';
  IF a4 < b4 THEN ok := 1 ELSE ok := 0 END;
  Out.Int(ok, 0); Out.Ln;

  (* 19. Same content in arrays *)
  b4 := 'ABC';
  IF a4 = b4 THEN ok := 1 ELSE ok := 0 END;
  Out.Int(ok, 0); Out.Ln;

  (* 20. Single-char string CONST assigned to CHAR *)
  ch := hex;
  Out.Char(ch); Out.Ln;

  (* 21. ORD of single-char string CONST: ORD(41X) = 65 *)
  Out.Int(ORD(hex), 0); Out.Ln;

  (* 22. Out.String with literal directly *)
  Out.String('Hi'); Out.Ln;

  (* 23. Out.String with string CONST *)
  Out.String(greet); Out.Ln;

  (* 24. Dedup: same literal twice *)
  Out.String('Hi'); Out.Ln;

  (* 25. UTF-8 output: Cyrillic *)
  Out.String('Привет'); Out.Ln;

  (* 26. Out.Char with non-ASCII *)
  Out.Char('Ы'); Out.Ln
END StringTest.
