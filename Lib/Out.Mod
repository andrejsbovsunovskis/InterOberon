MODULE Out; (**%RU:Вывод%LV:Izvade*)
IMPORT Platform, SYSTEM;

CONST
  bufCap = 1024; (**%RU:ёмкБуф%LV:buferaIet*)

VAR
  outBuf: ARRAY bufCap OF CHAR;
  outLen: INTEGER; (**%RU:длина,буф%LV:garums,buf*)

PROCEDURE Flush*; (**%RU:Опустошить%LV:Iztukšot*)
BEGIN
  IF outLen # 0 THEN
    Platform.WriteString(Platform.stdout, outBuf, 0, outLen);
    outLen := 0
  END
END Flush;

PROCEDURE Open*; (**%RU:Открыть%LV:Atvērt*)
BEGIN Flush
END Open;

PROCEDURE Char*(ch: CHAR); (**%RU:Литера,симв%LV:Litera,sim*)
BEGIN
  outBuf[outLen] := ch;
  INC(outLen);
  IF outLen = bufCap THEN Flush END
END Char;

PROCEDURE String*(s: ARRAY OF CHAR); (**%RU:Строка,строка%LV:Virkne,virkne*)
VAR len, i, j: INTEGER; (**%RU:же,и,длина%LV:j,i,garums*)
BEGIN
  len := 0; WHILE (len # LEN(s)) & (s[len] # 0X) DO INC(len) END;

  IF len # 0 THEN
    IF len >= bufCap - outLen THEN
      Flush;
      Platform.WriteString(Platform.stdout, s, 0, len)
    ELSE
      i := 0; j := outLen;
      WHILE i # len DO outBuf[j] := s[i]; INC(i); INC(j) END;
      INC(outLen, len)
    END
  END
END String;

PROCEDURE Ln*; (**%RU:Перенос%LV:Pārnese*)
BEGIN
  Char(0AX); Flush
END Ln;

PROCEDURE FillDigits(x: LONGINT; base: INTEGER; VAR digits: ARRAY OF CHAR): INTEGER;
  (**%RU:ЗапЦифр,знач,осн,цифры%LV:AizpCip,vērt,bāze,cipari*)
VAR n, d: INTEGER; (**%RU:д,н%LV:d,n*)
BEGIN
  n := 0;
  IF x = 0 THEN digits[0] := '0'; n := 1
  ELSE
    WHILE (x # 0) & (n # LEN(digits)) DO
      d := SHORT(x MOD base);
      IF d < 10 THEN digits[n] := CHR(d + ORD('0'))
      ELSE digits[n] := CHR(d - 10 + ORD('A'))
      END;
      x := x DIV base;
      INC(n)
    END
  END
RETURN n END FillDigits;

PROCEDURE Int*(x: LONGINT; n: INTEGER); (**%RU:Целое,знач,шир%LV:Veselais,vērt,plat*)
VAR digits: ARRAY 24 OF CHAR; (**%RU:цифры%LV:cipari*)
    nDig: INTEGER; (**%RU:чЦифр%LV:cipSk*)
BEGIN
  nDig := FillDigits(ABS(x), 10, digits);
  DEC(n, nDig);
  IF x < 0 THEN DEC(n) END;
  WHILE n > 0 DO Char(' '); DEC(n) END;
  IF x < 0 THEN Char('-') END;
  WHILE nDig # 0 DO DEC(nDig); Char(digits[nDig]) END
END Int;

PROCEDURE Hex*(x: LONGINT; n: INTEGER); (**%RU:Шестн,знач,шир%LV:Heks,vērt,plat*)
VAR digits: ARRAY 16 OF CHAR; (**%RU:цифры%LV:cipari*)
    nDig: INTEGER; (**%RU:чЦифр%LV:cipSk*)
BEGIN
  nDig := FillDigits(x, 16, digits);
  WHILE n > nDig DO Char('0'); DEC(n) END;
  WHILE nDig # 0 DO DEC(nDig); Char(digits[nDig]) END
END Hex;

PROCEDURE Real*(x: REAL; n: INTEGER); (**%RU:Вещ,знач,шир%LV:Reālais,vērt,plat*)
CONST sigDigits = 7; (**%RU:значЦифр%LV:vērtCip*)
VAR digits: ARRAY 8 OF INTEGER; (**%RU:цифры%LV:cipari*)
    expVal, i, intPart, expWidth, totalWidth, e: INTEGER;
    (**%RU:е,общШ,шЭксп,цЧаст,и,эксп%LV:e,kopPlat,eksPlat,vesD,i,eks*)
    neg, expNeg: BOOLEAN; (**%RU:экспОтриц,отриц%LV:eksNeg,neg*)
    m: REAL; (**%RU:м%LV:m*)
BEGIN
  IF x < 0.0 THEN neg := TRUE; m := -x ELSE neg := FALSE; m := x END;
  expVal := 0;
  IF m # 0.0 THEN
    WHILE m >= 10.0 DO m := m / 10.0; INC(expVal) END;
    WHILE m <  1.0 DO m := m * 10.0; DEC(expVal) END
  END;
  i := 0;
  WHILE i # sigDigits DO
    intPart := FLOOR(m);
    IF intPart < 0 THEN intPart := 0 END;
    IF intPart > 9 THEN intPart := 9 END;
    digits[i] := intPart;
    m := (m - FLT(intPart)) * 10.0;
    INC(i)
  END;
  IF expVal < 0 THEN expNeg := TRUE; e := -expVal ELSE expNeg := FALSE; e := expVal END;
  expWidth := 1; IF e >= 10 THEN INC(expWidth) END; IF e >= 100 THEN INC(expWidth) END;
  totalWidth := sigDigits + 2 + 1 + expWidth;
  IF neg OR expNeg THEN INC(totalWidth) END;
  IF ~expNeg THEN INC(totalWidth) END;
  IF neg THEN INC(totalWidth) END;
  WHILE n > totalWidth DO Char(' '); DEC(n) END;
  IF neg THEN Char('-') END;
  Char(CHR(digits[0] + ORD('0')));
  Char('.');
  i := 1; WHILE i # sigDigits DO Char(CHR(digits[i] + ORD('0'))); INC(i) END;
  Char('E');
  IF expNeg THEN Char('-') ELSE Char('+') END;
  IF e >= 100 THEN Char(CHR(e DIV 100 + ORD('0'))) END;
  IF e >= 10  THEN Char(CHR((e DIV 10) MOD 10 + ORD('0'))) END;
  Char(CHR(e MOD 10 + ORD('0')))
END Real;

PROCEDURE RealFix*(x: REAL; n, k: INTEGER); (**%RU:ВещФикс,знач,шир,дроб%LV:ReālaisFix,vērt,plat,daļ*)
VAR intDigits: ARRAY 16 OF CHAR; (**%RU:цЦифры%LV:vesCip*)
    nInt, width, i, d: INTEGER; (**%RU:д,и,ширина,чЦел%LV:d,i,platums,vesSk*)
    neg: BOOLEAN; (**%RU:отриц%LV:neg*)
    ip: LONGINT; (**%RU:цЧаст%LV:vesD*)
    frac, half: REAL; (**%RU:полов,дроб%LV:puse,daļa*)
BEGIN
  IF x < 0.0 THEN neg := TRUE; x := -x ELSE neg := FALSE END;
  IF k < 0 THEN k := 0 END;
  half := 0.5;
  i := 0; WHILE i # k DO half := half / 10.0; INC(i) END;
  x := x + half;
  ip := FLOOR(x);
  frac := x - FLT(SHORT(ip));
  nInt := FillDigits(ABS(ip), 10, intDigits);
  width := nInt;
  IF neg THEN INC(width) END;
  IF k > 0 THEN width := width + 1 + k END;
  WHILE n > width DO Char(' '); DEC(n) END;
  IF neg THEN Char('-') END;
  WHILE nInt # 0 DO DEC(nInt); Char(intDigits[nInt]) END;
  IF k > 0 THEN
    Char('.');
    i := 0;
    WHILE i # k DO
      frac := frac * 10.0;
      d := FLOOR(frac);
      IF d < 0 THEN d := 0 END;
      IF d > 9 THEN d := 9 END;
      Char(CHR(d + ORD('0')));
      frac := frac - FLT(d);
      INC(i)
    END
  END
END RealFix;

PROCEDURE LongReal*(x: LONGREAL; n: INTEGER); (**%RU:ДлинВещ,знач,шир%LV:GaraisReālais,vērt,plat*)
BEGIN Real(SYSTEM.VAL(REAL, x), n)
END LongReal;

PROCEDURE LongRealFix*(x: LONGREAL; n, k: INTEGER); (**%RU:ДлинВещФикс,знач,шир,дроб%LV:GaraisReālaisFix,vērt,plat,daļ*)
BEGIN RealFix(SYSTEM.VAL(REAL, x), n, k)
END LongRealFix;

BEGIN
  outLen := 0
END Out.
