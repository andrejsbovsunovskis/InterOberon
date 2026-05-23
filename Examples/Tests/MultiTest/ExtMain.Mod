MODULE ExtMain;
IMPORT Out, ExtLib;

TYPE
  Dog* = RECORD (ExtLib.Animal)
    barkLevel: INTEGER
  END;
  PDog = POINTER TO Dog;

PROCEDURE Run*;
VAR d: PDog; a: ExtLib.PAnimal;
BEGIN
  NEW(d); d.age := 7; d.barkLevel := 4;
  a := d;  (* PDog assignable to PAnimal via extension *)
  Out.Int(ExtLib.GetAge(a), 0); Out.Ln;
  IF a IS Dog THEN Out.String("Dog"); Out.Ln
  ELSE Out.String("notDog"); Out.Ln
  END;
  Out.Int(a(PDog).barkLevel, 0); Out.Ln;
  a(PDog).barkLevel := 99;
  Out.Int(d.barkLevel, 0); Out.Ln
END Run;

END ExtMain.
