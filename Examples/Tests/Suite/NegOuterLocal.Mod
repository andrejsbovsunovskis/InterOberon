MODULE NegOuterLocal;
PROCEDURE Outer;
  VAR x: INTEGER;
  PROCEDURE Inner;
  BEGIN x := 1 END Inner;
BEGIN Inner END Outer;
BEGIN END NegOuterLocal.
