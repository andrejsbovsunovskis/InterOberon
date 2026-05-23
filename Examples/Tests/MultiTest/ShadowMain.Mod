MODULE ShadowMain;
IMPORT Utf8, Out;

PROCEDURE Run*;
BEGIN
  Out.Int(Utf8.tag, 0); Out.Ln;
  Out.String("ok"); Out.Ln
END Run;

END ShadowMain.
