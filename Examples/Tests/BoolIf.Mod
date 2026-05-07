MODULE BoolIf;
IMPORT Out;
BEGIN
  IF TRUE THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END BoolIf.
