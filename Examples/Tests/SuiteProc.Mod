MODULE SuiteProc;
IMPORT Out;

TYPE
  IntProc = PROCEDURE(x: INTEGER);
  IntFunc = PROCEDURE(x: INTEGER): INTEGER;

VAR
  g, h: INTEGER;
  p: IntProc;
  f: IntFunc;

PROCEDURE Hello;
BEGIN
  Out.Int(42, 0); Out.Ln
END Hello;

PROCEDURE Add(a, b: INTEGER);
BEGIN
  Out.Int(a + b, 0); Out.Ln
END Add;

PROCEDURE Triple(x: INTEGER);
VAR r: INTEGER;
BEGIN
  r := x * 3;
  Out.Int(r, 0); Out.Ln
END Triple;

PROCEDURE Swap(VAR a, b: INTEGER);
VAR t: INTEGER;
BEGIN
  t := a;
  a := b;
  b := t
END Swap;

PROCEDURE PrintGlobal;
BEGIN
  Out.Int(g, 0); Out.Ln
END PrintGlobal;

PROCEDURE Outer;

  PROCEDURE Inner;
  BEGIN
    Out.Int(g, 0); Out.Ln
  END Inner;

BEGIN
  Inner
END Outer;

PROCEDURE Math;

  PROCEDURE Double(x: INTEGER);
  BEGIN
    Out.Int(x * 2, 0); Out.Ln
  END Double;

  PROCEDURE Square(x: INTEGER);
  VAR r: INTEGER;
  BEGIN
    r := x * x;
    Out.Int(r, 0); Out.Ln
  END Square;

BEGIN
  Double(7);
  Square(5)
END Math;

PROCEDURE Deep;

  PROCEDURE Mid;

    PROCEDURE Bot;
    BEGIN
      Out.Int(g, 0); Out.Ln
    END Bot;

  BEGIN
    Bot
  END Mid;

BEGIN
  Mid
END Deep;

PROCEDURE WithLocal;
VAR a: INTEGER;

  PROCEDURE Show;
  BEGIN
    Out.Int(g, 0); Out.Ln
  END Show;

BEGIN
  a := 10;
  g := a;
  Show
END WithLocal;

PROCEDURE Siblings;

  PROCEDURE A(x: INTEGER);
  BEGIN
    Out.Int(x, 0); Out.Ln
  END A;

  PROCEDURE B;
  BEGIN
    A(55);
    A(66)
  END B;

BEGIN
  B
END Siblings;

PROCEDURE CallOuter(n: INTEGER);

  PROCEDURE Step;
  BEGIN
    Out.Int(g, 0); Out.Ln;
    DEC(g);
    IF g > 0 THEN CallOuter(g) END
  END Step;

BEGIN
  Step
END CallOuter;

PROCEDURE UseConst;
CONST c = 77;

  PROCEDURE Inner;
  BEGIN
    Out.Int(c, 0); Out.Ln
  END Inner;

  PROCEDURE Deeper;
  CONST d = 88;

    PROCEDURE Bot;
    BEGIN
      Out.Int(c + d, 0); Out.Ln
    END Bot;

  BEGIN
    Bot
  END Deeper;

BEGIN
  Inner;
  Deeper
END UseConst;

PROCEDURE RFuncAll;

  PROCEDURE DoubleF(n: INTEGER): INTEGER;
  RETURN n * 2 END DoubleF;

  PROCEDURE Sum(n: INTEGER): INTEGER;
  VAR i, s: INTEGER;
  BEGIN
    s := 0;
    FOR i := 1 TO n DO s := s + i END
  RETURN s END Sum;

  PROCEDURE Fact(n: INTEGER): INTEGER;
  VAR r: INTEGER;
  BEGIN
    r := 1;
    WHILE n > 1 DO r := r * n; DEC(n) END
  RETURN r END Fact;

  PROCEDURE AddF(a, b: INTEGER): INTEGER;
  RETURN a + b END AddF;

  PROCEDURE Sq(n: INTEGER): INTEGER;
  RETURN n * n END Sq;

BEGIN
  Out.Int(DoubleF(5), 0); Out.Ln;
  Out.Int(Sum(100), 0); Out.Ln;
  Out.Int(Fact(6), 0); Out.Ln;
  Out.Int(AddF(Sum(5), Sum(10)), 0); Out.Ln;
  Out.Int(Sq(3) + Sq(4), 0); Out.Ln;
  Out.Int(DoubleF(DoubleF(3)), 0); Out.Ln
END RFuncAll;

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
  Hello;
  Add(10, 20);
  Triple(7);
  g := 100; h := 200;
  Swap(g, h);
  Out.Int(g, 0); Out.Ln;
  Out.Int(h, 0); Out.Ln;
  Add(1, 2);
  Add(3, 4);
  Triple(10);

  g := 42;
  Outer;
  Math;
  g := 99;
  Deep;
  WithLocal;
  Siblings;
  g := 3;
  CallOuter(g);
  UseConst;

  RFuncAll;

  p := PrintDouble;
  p(5);
  p(10);
  p := PrintTriple;
  p(5);
  p(10);
  f := Square;
  Out.Int(f(4), 0); Out.Ln;
  f := Cube;
  Out.Int(f(3), 0); Out.Ln;
  Apply(Square, 5);
  Apply(Cube, 2);
  Out.Int(ApplyAndAdd(Square, 3, 4), 0); Out.Ln;
  Out.Int(ApplyAndAdd(Cube, 2, 3), 0); Out.Ln
END SuiteProc.
