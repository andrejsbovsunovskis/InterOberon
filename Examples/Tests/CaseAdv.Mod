MODULE CaseAdv;
IMPORT Out;
VAR x, res: INTEGER;
BEGIN
  (* 1. CASE with large range *)
  x := 50;
  CASE x OF
    0..25: res := 1
  | 26..50: res := 2
  | 51..100: res := 3
  ELSE res := 0
  END;
  Out.Int(res, 0); Out.Ln;

  (* 2. CASE with first of range *)
  x := 0;
  CASE x OF
    0..10: res := 10
  | 11..20: res := 20
  ELSE res := 0
  END;
  Out.Int(res, 0); Out.Ln;

  (* 3. CASE with last of range *)
  x := 10;
  CASE x OF
    0..10: res := 10
  | 11..20: res := 20
  ELSE res := 0
  END;
  Out.Int(res, 0); Out.Ln;

  (* 4. CASE with mixed labels and ranges *)
  x := 7;
  CASE x OF
    1, 3, 5: res := 1
  | 2, 4, 6: res := 2
  | 7..10: res := 3
  ELSE res := 0
  END;
  Out.Int(res, 0); Out.Ln;

  (* 5. CASE falls to ELSE *)
  x := 999;
  CASE x OF
    1: res := 1
  | 2: res := 2
  ELSE res := -1
  END;
  Out.Int(res, 0); Out.Ln;

  (* 6. Multiple CASE statements in sequence *)
  x := 3;
  CASE x OF
    1: res := 10
  | 2: res := 20
  | 3: res := 30
  END;
  Out.Int(res, 0); Out.Char(' ');
  x := 1;
  CASE x OF
    1: res := 100
  | 2: res := 200
  | 3: res := 300
  END;
  Out.Int(res, 0); Out.Ln;

  (* 7. CASE inside FOR loop *)
  FOR x := 1 TO 4 DO
    CASE x OF
      1: Out.Char('A')
    | 2: Out.Char('B')
    | 3: Out.Char('C')
    | 40: Out.Char('D')
    END
  END;
  Out.Ln;

  (* 8. CASE with negative range *)
  x := -3;
  CASE x OF
    -5..-1: res := 1
  | 0..5: res := 2
  ELSE res := 0
  END;
  Out.Int(res, 0); Out.Ln
END CaseAdv.
