MODULE DeepOpenIdx;
(* Open-array index via separate variables (expr i+j in index is a known compiler bug). *)
IMPORT Out;

VAR a: ARRAY 4 OF INTEGER; s: INTEGER;

PROCEDURE SumAt(x: ARRAY OF INTEGER; i, j: INTEGER): INTEGER;
VAR t: INTEGER;
BEGIN
  t := x[i] + x[j];
  RETURN t
END SumAt;

BEGIN
  a[0] := 10; a[1] := 20; a[2] := 30; a[3] := 40;
  s := SumAt(a, 1, 3);
  Out.Int(s, 0); Out.Ln;
  s := SumAt(a, 0, 2);
  Out.Int(s, 0); Out.Ln
END DeepOpenIdx.
