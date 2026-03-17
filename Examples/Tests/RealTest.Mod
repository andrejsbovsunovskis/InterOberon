MODULE RealTest;
IMPORT Out;
VAR r, s: REAL; i: INTEGER;
BEGIN
  (* 1. FLT and FLOOR: FLT(7) → 7.0 → FLOOR → 7 *)
  r := FLT(7);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 2. Float addition: FLT(3) + FLT(4) = 7 *)
  r := FLT(3) + FLT(4);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 3. Float subtraction: FLT(10) - FLT(3) = 7 *)
  r := FLT(10) - FLT(3);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 4. Float multiplication: FLT(6) * FLT(5) = 30 *)
  r := FLT(6) * FLT(5);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 5. Float division: FLT(20) / FLT(4) = 5 *)
  r := FLT(20) / FLT(4);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 6. Float division non-integer: FLT(7) / FLT(2) = 3.5 → FLOOR = 3 *)
  r := FLT(7) / FLT(2);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 7. Float negation: -FLT(5) + FLT(12) = 7 *)
  r := -FLT(5) + FLT(12);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 8. Real literal: 3.14 → FLOOR = 3 *)
  r := 3.14;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 9. Real literal: 100.5 → FLOOR = 100 *)
  r := 100.5;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 10. Real literal arithmetic: 2.5 * 4.0 = 10.0 → FLOOR = 10 *)
  r := 2.5 * 4.0;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 11. Real comparison: 3.0 > 2.0 → 1 *)
  IF FLT(3) > FLT(2) THEN i := 1 ELSE i := 0 END;
  Out.Int(i, 0); Out.Ln;

  (* 12. Real comparison: 2.0 < 5.0 → 1 *)
  IF FLT(2) < FLT(5) THEN i := 1 ELSE i := 0 END;
  Out.Int(i, 0); Out.Ln;

  (* 13. Real comparison: 4.0 = 4.0 → 1 *)
  IF FLT(4) = FLT(4) THEN i := 1 ELSE i := 0 END;
  Out.Int(i, 0); Out.Ln;

  (* 14. Real comparison: 4.0 # 5.0 → 1 *)
  IF FLT(4) # FLT(5) THEN i := 1 ELSE i := 0 END;
  Out.Int(i, 0); Out.Ln;

  (* 15. Variable arithmetic: r=10.0, s=3.0, r/s → FLOOR = 3 *)
  r := FLT(10); s := FLT(3);
  r := r / s;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 16. Fractional test: FLT(7)/FLT(2) = 3.5, (r-FLT(FLOOR(r)))*FLT(10) → FLOOR = 5 *)
  r := FLT(7) / FLT(2);
  r := r - FLT(FLOOR(r));
  r := r * FLT(10);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 17. Real literal 0.5: FLOOR(0.5*6.0) = 3 *)
  r := 0.5 * 6.0;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 18. Variable comparison: r=1.5, s=2.5, r < s → 1 *)
  r := 1.5; s := 2.5;
  IF r < s THEN i := 1 ELSE i := 0 END;
  Out.Int(i, 0); Out.Ln;

  (* 19. Large value: FLT(1000) * FLT(1000) = 1000000 *)
  r := FLT(1000) * FLT(1000);
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln;

  (* 20. Real literal 0.0: FLOOR = 0 *)
  r := 0.0;
  i := FLOOR(r);
  Out.Int(i, 0); Out.Ln
END RealTest.
