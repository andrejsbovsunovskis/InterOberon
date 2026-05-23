MODULE Main;
IMPORT Out, Lib;

PROCEDURE Run*;
BEGIN
  Out.String('Initial: '); Lib.Show;
  Lib.Add(5);
  Out.String('After +5: '); Lib.Show;
  Lib.Add(20);
  Out.String('After +20: '); Lib.Show
END Run;

BEGIN
  Out.String('Main initialized'); Out.Ln
END Main.
