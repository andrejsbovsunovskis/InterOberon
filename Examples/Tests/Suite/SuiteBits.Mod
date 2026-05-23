MODULE SuiteBits;
IMPORT Out, SYSTEM;

VAR
  ts: TINYSET;
  ss: SHORTSET;
  s: SET;
  ls: LONGSET;
  res: INTEGER;

BEGIN
  IF BITS(0) = {} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF BITS(1) = {0} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF BITS(3) = {0, 1} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF BITS(0FFFFFFFFH) = {0..31} THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;

  IF ORD(BITS(7)) = 7 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;

  ts := BITS(10);
  IF ORD(ts) = 10 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF BITS(ORD(ts)) = ts THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;

  ss := BITS(5);
  IF ORD(ss) = 5 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;

  s := BITS(0FFFFFFFFH);
  IF ORD(s) = -1 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  IF SYSTEM.VAL(SET, -1) = s THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln
END SuiteBits.
