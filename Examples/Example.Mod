MODULE Example;
IMPORT Out;
VAR
  a, b, c: INTEGER;
BEGIN
  (* IF / ELSE *)
  a := -1;
  IF a < 2 THEN Out.Char('Y') ELSE Out.Char('N') END; Out.Ln;  (* Y 0A *)

  (* WHILE *)
  b := 48;
  WHILE b < 53 DO
    Out.Int(b, 0);
    INC(b, 1)
  END;
  Out.Ln;  (* 00 01 02 03 04 0A *)

  (* REPEAT *)
  c := 0;
  REPEAT
    Out.Int(c, 0);
    c := c + 1
  UNTIL c = 3;
  Out.Ln   (* 00 01 02 0A *)
END Example.