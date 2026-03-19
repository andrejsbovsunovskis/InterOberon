MODULE BoolTest;
IMPORT Out;
VAR a, b: BOOLEAN; i: INTEGER;
BEGIN
  (* 1. TRUE literal → 1 *)
  a := TRUE;
  IF a THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 2. FALSE literal → 0 *)
  a := FALSE;
  IF a THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 3. NOT TRUE = FALSE → 0 *)
  a := TRUE;
  IF ~a THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 4. NOT FALSE = TRUE → 1 *)
  a := FALSE;
  IF ~a THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 5. TRUE & TRUE = TRUE → 1 *)
  a := TRUE; b := TRUE;
  IF a & b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 6. TRUE & FALSE = FALSE → 0 *)
  a := TRUE; b := FALSE;
  IF a & b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 7. FALSE & TRUE = FALSE → 0 *)
  a := FALSE; b := TRUE;
  IF a & b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 8. FALSE & FALSE = FALSE → 0 *)
  a := FALSE; b := FALSE;
  IF a & b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 9. TRUE OR TRUE = TRUE → 1 *)
  a := TRUE; b := TRUE;
  IF a OR b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 10. TRUE OR FALSE = TRUE → 1 *)
  a := TRUE; b := FALSE;
  IF a OR b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 11. FALSE OR TRUE = TRUE → 1 *)
  a := FALSE; b := TRUE;
  IF a OR b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 12. FALSE OR FALSE = FALSE → 0 *)
  a := FALSE; b := FALSE;
  IF a OR b THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 13. Complex condition: (5 > 3) → 1 *)
  IF 5 > 3 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 14. Complex condition: (2 > 3) → 0 *)
  IF 2 > 3 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 15. ORD of TRUE = 1 *)
  Out.Int(ORD(TRUE), 0); Out.Ln;

  (* 16. ORD of FALSE = 0 *)
  Out.Int(ORD(FALSE), 0); Out.Ln;

  (* 17. Short-circuit AND: FALSE & anything should not eval right side *)
  i := 0;
  a := FALSE;
  IF a & (1 = 1) THEN i := 1 END;
  Out.Int(i, 0); Out.Ln;

  (* 18. Short-circuit OR: TRUE OR anything should not eval right side *)
  i := 0;
  a := TRUE;
  IF a OR (1 = 0) THEN i := 1 END;
  Out.Int(i, 0); Out.Ln;

  (* 19. Complex: (TRUE & FALSE) OR TRUE = TRUE → 1 *)
  IF (TRUE & FALSE) OR TRUE THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* 20. Complex: TRUE & (FALSE OR TRUE) = TRUE → 1 *)
  IF TRUE & (FALSE OR TRUE) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END BoolTest.
