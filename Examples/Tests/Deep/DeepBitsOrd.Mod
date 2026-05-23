MODULE DeepBitsOrd;
IMPORT Out;
VAR ts: TINYSET; i: INTEGER; res: INTEGER;
BEGIN
  ts := BITS(10);
  IF ORD(ts) = 10 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  i := 10;
  ts := BITS(i);
  IF ORD(ts) = 10 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF BITS(ORD(ts)) = ts THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF BITS(ORD(ts)) = BITS(10) THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END DeepBitsOrd.
