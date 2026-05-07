MODULE FuncAll;
IMPORT Out;

(* Simple function *)
PROCEDURE Double(n: INTEGER): INTEGER;
RETURN n * 2 END Double;

(* Function with body and FOR *)
PROCEDURE Sum(n: INTEGER): INTEGER;
VAR i, s: INTEGER;
BEGIN
  s := 0;
  FOR i := 1 TO n DO s := s + i END
RETURN s END Sum;

(* Function with WHILE *)
PROCEDURE Fact(n: INTEGER): INTEGER;
VAR r: INTEGER;
BEGIN
  r := 1;
  WHILE n > 1 DO r := r * n; DEC(n) END
RETURN r END Fact;

(* Nested function calls *)
PROCEDURE Add(a, b: INTEGER): INTEGER;
RETURN a + b END Add;

(* Function in expression *)
PROCEDURE Square(n: INTEGER): INTEGER;
RETURN n * n END Square;

BEGIN
  Out.Int(Double(5), 0); Out.Ln;
  Out.Int(Sum(100), 0); Out.Ln;
  Out.Int(Fact(6), 0); Out.Ln;
  Out.Int(Add(Sum(5), Sum(10)), 0); Out.Ln;
  Out.Int(Square(3) + Square(4), 0); Out.Ln;
  Out.Int(Double(Double(3)), 0); Out.Ln
END FuncAll.
