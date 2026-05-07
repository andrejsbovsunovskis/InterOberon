MODULE ProcTyp;
IMPORT Out;

TYPE
  IntProc = PROCEDURE(x: INTEGER);
  IntFunc = PROCEDURE(x: INTEGER): INTEGER;

VAR
  p: IntProc;
  f: IntFunc;

PROCEDURE PrintDouble(n: INTEGER);
BEGIN
  Out.Int(n * 2, 0); Out.Ln
END PrintDouble;

PROCEDURE PrintTriple(n: INTEGER);
BEGIN
  Out.Int(n * 3, 0); Out.Ln
END PrintTriple;

PROCEDURE Square(n: INTEGER): INTEGER;
RETURN n * n END Square;

PROCEDURE Cube(n: INTEGER): INTEGER;
RETURN n * n * n END Cube;

PROCEDURE Apply(fn: IntFunc; val: INTEGER);
BEGIN
  Out.Int(fn(val), 0); Out.Ln
END Apply;

PROCEDURE ApplyAndAdd(fn: IntFunc; a, b: INTEGER): INTEGER;
RETURN fn(a) + fn(b) END ApplyAndAdd;

BEGIN
  (* Procedure type variables *)
  p := PrintDouble;
  p(5);
  p(10);
  p := PrintTriple;
  p(5);
  p(10);
  (* Function type variables *)
  f := Square;
  Out.Int(f(4), 0); Out.Ln;
  f := Cube;
  Out.Int(f(3), 0); Out.Ln;
  (* Passing functions to procedures *)
  Apply(Square, 5);
  Apply(Cube, 2);
  (* Passing functions to function procedures *)
  Out.Int(ApplyAndAdd(Square, 3, 4), 0); Out.Ln;
  Out.Int(ApplyAndAdd(Cube, 2, 3), 0); Out.Ln
END ProcTyp.
