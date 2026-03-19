MODULE RealAdv;
IMPORT Out;
VAR r, s: REAL; i: INTEGER;
BEGIN
  (* 1. Accumulate small values: 0.1 * 10 iterations → ~1.0 *)
  r := 0.0;
  FOR i := 1 TO 10 DO
    r := r + 0.1
  END;
  (* Should be close to 1.0 -> FLOOR = 0 (floating point may be 0.999...) or 1 *)
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 2. Multiplication chain: 1.5 * 2.0 = 3.0 *)
  r := 1.5 * 2.0;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 3. Division: 22.0 / 7.0 ≈ 3.14... → FLOOR = 3 *)
  r := 22.0 / 7.0;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 4. Negative real: FLOOR(-2.5) *)
  r := -2.5;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 5. Real comparison chain *)
  r := 1.5; s := 2.5;
  IF r < s THEN Out.Int(1, 0) END;
  IF r <= s THEN Out.Int(1, 0) END;
  IF s > r THEN Out.Int(1, 0) END;
  IF s >= r THEN Out.Int(1, 0) END;
  IF r # s THEN Out.Int(1, 0) END;
  Out.Ln;

  (* 6. Real equality *)
  r := 3.0;
  s := FLT(3);
  IF r = s THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 7. Power via loop: 2.0^8 = 256 *)
  r := 1.0;
  FOR i := 1 TO 8 DO
    r := r * 2.0
  END;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 8. Mixed FLT/FLOOR: FLOOR(FLT(100) / FLT(3)) = 33 *)
  i := FLOOR(FLT(100) / FLT(3));
  Out.Int(i, 0); Out.Ln;

  (* 9. Real subtraction: 10.7 - 3.2 ≈ 7.5 → FLOOR = 7 *)
  r := 10.7 - 3.2;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 10. Large real: 1000000.0 → FLOOR = 1000000 *)
  r := 1000000.0;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln
END RealAdv.
