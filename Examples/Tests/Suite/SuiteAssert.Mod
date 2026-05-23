MODULE SuiteAssert;
IMPORT Out;

VAR ok: BOOLEAN;

BEGIN
  ASSERT(TRUE);
  ok := TRUE;
  ASSERT(ok);
  Out.String('ok'); Out.Ln
END SuiteAssert.
