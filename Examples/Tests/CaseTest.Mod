MODULE CaseTest;
IMPORT Out;
VAR x, res: INTEGER;
    ch: CHAR;
BEGIN
  (* 1. Simple CASE *)
  x := 2;
  CASE x OF
    1: res := 10 |
    2: res := 20 |
    3: res := 30
  END;
  Out.Int(res, 0); Out.Ln;

  (* 2. CASE with ELSE *)
  x := 5;
  CASE x OF
    1: res := 10 |
    2: res := 20
  ELSE res := 99
  END;
  Out.Int(res, 0); Out.Ln;

  (* 3. CASE with multiple labels *)
  x := 4;
  CASE x OF
    1, 3, 5: res := 1 |
    2, 4, 6: res := 2
  ELSE res := 0
  END;
  Out.Int(res, 0); Out.Ln;

  (* 4. CASE with range *)
  x := 7;
  CASE x OF
    0..5: res := 1 |
    6..10: res := 2 |
    11..20: res := 3
  ELSE res := 0
  END;
  Out.Int(res, 0); Out.Ln;

  (* 5. CASE with character *)
  ch := 'B';
  CASE ORD(ch) OF
    65: res := 1 |
    66: res := 2 |
    67: res := 3
  ELSE res := 0
  END;
  Out.Int(res, 0); Out.Ln;

  (* 6. CASE with negative values *)
  x := -1;
  CASE x OF
    -2: res := 1 |
    -1: res := 2 |
    0: res := 3
  ELSE res := 0
  END;
  Out.Int(res, 0); Out.Ln;

  (* 7. CASE first match *)
  x := 1;
  CASE x OF
    1: res := 100 |
    2: res := 200 |
    3: res := 300
  END;
  Out.Int(res, 0); Out.Ln;

  (* 8. CASE last match *)
  x := 3;
  CASE x OF
    1: res := 100 |
    2: res := 200 |
    3: res := 300
  END;
  Out.Int(res, 0); Out.Ln
END CaseTest.
