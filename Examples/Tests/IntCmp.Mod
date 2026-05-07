MODULE IntCmp;
IMPORT Out;
BEGIN
  IF 1 < 2 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END IntCmp.
