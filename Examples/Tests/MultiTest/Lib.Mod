MODULE Lib; (**%RU:Библ*)
IMPORT Out;

VAR counter*: INTEGER; (**%RU:счётчик*)

PROCEDURE Add*(n: INTEGER);
BEGIN counter := counter + n
END Add;

PROCEDURE Show*;
BEGIN Out.Int(counter, 0); Out.Ln
END Show;

BEGIN
  counter := 100;
  Out.String('Lib initialized'); Out.Ln
END Lib.
