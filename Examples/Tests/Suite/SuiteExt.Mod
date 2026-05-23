MODULE SuiteExt;
IMPORT Out;

TYPE
  Animal = RECORD
    age: INTEGER;
    weight: INTEGER
  END;
  PAnimal = POINTER TO Animal;

  Dog = RECORD (Animal)
    barkLevel: INTEGER
  END;
  PDog = POINTER TO Dog;

  Puppy = RECORD (Dog)
    cuteness: INTEGER
  END;
  PPuppy = POINTER TO Puppy;

  Cat = RECORD (Animal)
    purrLevel: INTEGER
  END;
  PCat = POINTER TO Cat;

PROCEDURE BasicExtPart;
VAR d: Dog;
BEGIN
  d.age := 5;
  d.weight := 30;
  d.barkLevel := 7;
  Out.Int(d.age, 0); Out.Char(' ');
  Out.Int(d.weight, 0); Out.Char(' ');
  Out.Int(d.barkLevel, 0); Out.Ln
END BasicExtPart;

PROCEDURE TwoLevelPart;
VAR pp: Puppy;
BEGIN
  pp.age := 1;
  pp.weight := 5;
  pp.barkLevel := 3;
  pp.cuteness := 10;
  Out.Int(pp.age, 0); Out.Char(' ');
  Out.Int(pp.weight, 0); Out.Char(' ');
  Out.Int(pp.barkLevel, 0); Out.Char(' ');
  Out.Int(pp.cuteness, 0); Out.Ln
END TwoLevelPart;

PROCEDURE PointerIs;
VAR a: PAnimal; d: PDog; p: PPuppy; c: PCat;
BEGIN
  NEW(d); d.age := 4; d.barkLevel := 9;
  NEW(p); p.age := 2; p.cuteness := 100;
  NEW(c); c.age := 3; c.purrLevel := 5;

  a := d;
  IF a IS Dog THEN Out.String("a-is-Dog"); Out.Ln END;
  IF a IS Puppy THEN Out.String("a-is-Puppy") ELSE Out.String("a-not-Puppy") END; Out.Ln;
  IF a IS Cat THEN Out.String("a-is-Cat") ELSE Out.String("a-not-Cat") END; Out.Ln;
  IF a IS Animal THEN Out.String("a-is-Animal"); Out.Ln END;

  a := p;
  IF a IS Dog THEN Out.String("p-is-Dog"); Out.Ln END;
  IF a IS Puppy THEN Out.String("p-is-Puppy"); Out.Ln END;
  IF a IS Animal THEN Out.String("p-is-Animal"); Out.Ln END;

  a := c;
  IF a IS Dog THEN Out.String("c-is-Dog") ELSE Out.String("c-not-Dog") END; Out.Ln;
  IF a IS Cat THEN Out.String("c-is-Cat"); Out.Ln END
END PointerIs;

PROCEDURE TypeGuardPart;
VAR a: PAnimal; d: PDog;
BEGIN
  NEW(d); d.age := 7; d.barkLevel := 11;
  a := d;
  Out.Int(a(PDog).barkLevel, 0); Out.Ln;
  a(PDog).barkLevel := 22;
  Out.Int(d.barkLevel, 0); Out.Ln
END TypeGuardPart;

PROCEDURE TakeAnimal(VAR a: Animal);
BEGIN
  IF a IS Dog THEN Out.String('dog') ELSE Out.String('not dog') END;
  Out.Ln
END TakeAnimal;

PROCEDURE TakeDogPar(VAR a: Animal);
BEGIN
  IF a IS Dog THEN Out.String('dog') ELSE Out.String('no') END;
  Out.Ln
END TakeDogPar;

PROCEDURE VarRecordIsPart;
VAR d: Dog;
BEGIN
  d.age := 3; d.barkLevel := 7;
  TakeAnimal(d);
  d.age := 1; d.barkLevel := 9;
  TakeDogPar(d);
  Out.Int(d.barkLevel, 0); Out.Ln
END VarRecordIsPart;

PROCEDURE Describe(VAR a: PAnimal);
BEGIN
  Out.Int(a.age, 0); Out.Char(':');
  IF a IS Puppy THEN Out.String("puppy")
  ELSIF a IS Dog THEN Out.String("dog")
  ELSIF a IS Cat THEN Out.String("cat")
  ELSE Out.String("animal")
  END;
  Out.Ln
END Describe;

PROCEDURE PolymorphicPart;
VAR d: PDog; p: PPuppy; c: PCat; a: PAnimal;
BEGIN
  NEW(d); d.age := 10;
  NEW(p); p.age := 1;
  NEW(c); c.age := 4;
  a := d; Describe(a);
  a := p; Describe(a);
  a := c; Describe(a)
END PolymorphicPart;

(* Regression: Out.Int with type-guard field actual (ABI register placement). *)
PROCEDURE TgMiniPart;
VAR a: PAnimal; d: PDog;
BEGIN
  NEW(d); d.age := 1; d.weight := 2; d.barkLevel := 11;
  a := d;
  Out.Int(a(PDog).barkLevel, 0); Out.Ln
END TgMiniPart;

PROCEDURE TgMiniAPart;
VAR a: PAnimal; d: PDog; t: INTEGER;
BEGIN
  NEW(d); d.barkLevel := 11; a := d;
  t := a(PDog).barkLevel;
  Out.Int(t, 0); Out.Ln
END TgMiniAPart;

PROCEDURE TgMiniDPart;
VAR d: PDog;
BEGIN
  NEW(d); d.barkLevel := 11;
  Out.Int(d.barkLevel, 0); Out.Ln
END TgMiniDPart;

BEGIN
  BasicExtPart;
  TwoLevelPart;
  PointerIs;
  TypeGuardPart;
  PolymorphicPart;
  TgMiniPart;
  TgMiniAPart;
  TgMiniDPart;
  VarRecordIsPart
END SuiteExt.
