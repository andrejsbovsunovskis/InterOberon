MODULE OutFmt;
IMPORT Out;
VAR i: INTEGER;
BEGIN
  (* 1. Basic print *)
  Out.Int(42, 0); Out.Ln;

  (* 2. Negative number *)
  Out.Int(-7, 0); Out.Ln;

  (* 3. Zero *)
  Out.Int(0, 0); Out.Ln;

  (* 4. Large number *)
  Out.Int(123456, 0); Out.Ln;

  (* 5. Multiple Out.Char for formatted output *)
  Out.Char('[');
  Out.Int(99, 0);
  Out.Char(']');
  Out.Ln;

  (* 6. Print a separator line *)
  FOR i := 0 TO 19 DO
    Out.Char('-')
  END;
  Out.Ln;

  (* 7. Table-like output using Char *)
  FOR i := 1 TO 5 DO
    Out.Int(i, 0);
    Out.Char(':');
    Out.Int(i * i, 0);
    Out.Ln
  END;

  (* 8. Print alphabet A-J *)
  FOR i := 0 TO 9 DO
    Out.Char(CHR(65 + i))
  END;
  Out.Ln;

  (* 9. Mixed chars and ints *)
  Out.Char('(');
  Out.Int(1, 0);
  Out.Char('+');
  Out.Int(2, 0);
  Out.Char('=');
  Out.Int(3, 0);
  Out.Char(')');
  Out.Ln;

  (* 10. Multiple lines *)
  Out.Int(111, 0); Out.Ln;
  Out.Int(222, 0); Out.Ln;
  Out.Int(333, 0); Out.Ln
END OutFmt.
