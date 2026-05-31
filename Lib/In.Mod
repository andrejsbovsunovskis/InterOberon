MODULE In; (**%RU:Ввод%LV:Ievade*)
IMPORT Out, Platform, SYSTEM;

VAR
  Done*: BOOLEAN;
  buf: ARRAY 2 OF CHAR;
  bufLen: INTEGER; (**%RU:длБуф,буф,Готово%LV:bufGar,buf,Pabeigts*)

PROCEDURE IsDigit(ch: CHAR): BOOLEAN; (**%RU:Цифра,симв%LV:IrCipars,sim*)
RETURN ('0' <= ch) & (ch <= '9') END IsDigit;

(** Fills buf from stdin when empty. Supplementary UTF-8 uses two slots. *)
PROCEDURE Refill; (**%RU:Пополнить%LV:Papildināt*)
VAR hi, lo: CHAR; (**%RU:мл,ст%LV:zem,aug*)
    n: INTEGER; (**%RU:н%LV:n*)
BEGIN
  IF Done THEN
    Out.Flush;
    n := Platform.ReadCharEx(Platform.stdin, hi, lo);
    IF n <= 0 THEN Done := FALSE
    ELSE
      buf[0] := hi;
      IF lo # 0X THEN buf[1] := lo; bufLen := 2 ELSE bufLen := 1 END
    END
  END
END Refill;

PROCEDURE Peek(VAR ch: CHAR); (**%RU:Заглянуть,симв%LV:Ieskatīt,sim*)
BEGIN
  IF bufLen = 0 THEN Refill END;
  IF bufLen > 0 THEN ch := buf[0] ELSE ch := 0X END
END Peek;

(** Consumes front of buf. Sets ch on success. *)
PROCEDURE Take(VAR ch: CHAR); (**%RU:Взять,симв%LV:Paņemt,sim*)
BEGIN
  IF bufLen = 0 THEN Refill END;
  IF bufLen > 0 THEN
    ch := buf[0];
    IF bufLen = 1 THEN bufLen := 0
    ELSE buf[0] := buf[1]; bufLen := 1
    END
  ELSE ch := 0X
  END
END Take;

PROCEDURE Open*; (**%RU:Открыть%LV:Atvērt*)
BEGIN
  Done := TRUE; bufLen := 0
END Open;

PROCEDURE Char*(VAR ch: CHAR); (**%RU:Литера,симв%LV:Litera,sim*)
BEGIN
  IF Done THEN Take(ch) ELSE ch := 0X END
END Char;

PROCEDURE LongInt*(VAR i: LONGINT); (**%RU:ДлинЦел,знач%LV:GarsVeselais,vērt*)
VAR ch: CHAR; (**%RU:симв%LV:sim*)
    v: LONGINT; (**%RU:в%LV:v*)
    neg, sawDigit: BOOLEAN; (**%RU:бЦифр,отриц%LV:irCip,neg*)
BEGIN
  i := 0;
  IF Done THEN
    Peek(ch);
    WHILE Done & (ch <= ' ') DO Take(ch); Peek(ch) END;
    IF Done & (ch = '-') THEN neg := TRUE; Take(ch) ELSE neg := FALSE END;
    v := 0; sawDigit := FALSE;
    Peek(ch);
    WHILE Done & IsDigit(ch) DO
      Take(ch);
      v := v * 10 + ORD(ch) - ORD('0');
      sawDigit := TRUE;
      Peek(ch)
    END;
    IF ~sawDigit THEN Done := FALSE
    ELSE
      IF neg THEN i := -v ELSE i := v END;
      IF Done & (ch <= ' ') THEN Take(ch) END
    END
  END
END LongInt;

PROCEDURE Int*(VAR i: INTEGER); (**%RU:Целое,знач%LV:Veselais,vērt*)
VAR h: LONGINT; (**%RU:длин%LV:gars*)
BEGIN
  LongInt(h);
  i := SHORT(h)
END Int;

PROCEDURE Real*(VAR x: REAL); (**%RU:Вещ,знач%LV:Reālais,vērt*)
VAR ch: CHAR; (**%RU:симв%LV:sim*)
    mantissa: REAL; (**%RU:мант%LV:mant*)
    expVal, fracDigits, j: INTEGER; (**%RU:же,дробЦ,эксп%LV:j,daļC,eks*)
    neg, expNeg, sawDigit: BOOLEAN; (**%RU:бЦифр,экспОтриц,отриц%LV:irCip,eksNeg,neg*)
BEGIN
  x := 0.0;
  IF Done THEN
    Peek(ch);
    WHILE Done & (ch <= ' ') DO Take(ch); Peek(ch) END;
    neg := FALSE;
    IF Done & (ch = '-') THEN neg := TRUE; Take(ch)
    ELSIF Done & (ch = '+') THEN Take(ch)
    END;
    mantissa := 0.0; sawDigit := FALSE; fracDigits := 0;
    Peek(ch);
    WHILE Done & IsDigit(ch) DO
      Take(ch);
      mantissa := mantissa * 10.0 + FLT(ORD(ch) - ORD('0'));
      sawDigit := TRUE;
      Peek(ch)
    END;
    IF Done & (ch = '.') THEN
      Take(ch);
      Peek(ch);
      WHILE Done & IsDigit(ch) DO
        Take(ch);
        mantissa := mantissa * 10.0 + FLT(ORD(ch) - ORD('0'));
        INC(fracDigits);
        sawDigit := TRUE;
        Peek(ch)
      END
    END;
    IF ~sawDigit THEN Done := FALSE
    ELSE
      expVal := 0;
      IF Done & ((ch = 'E') OR (ch = 'e')) THEN
        expNeg := FALSE;
        Take(ch);
        IF Done THEN
          Peek(ch);
          IF ch = '-' THEN expNeg := TRUE; Take(ch)
          ELSIF ch = '+' THEN Take(ch)
          END
        END;
        Peek(ch);
        WHILE Done & IsDigit(ch) DO
          Take(ch);
          expVal := expVal * 10 + ORD(ch) - ORD('0');
          Peek(ch)
        END;
        IF expNeg THEN expVal := -expVal END
      END;
      expVal := expVal - fracDigits;
      IF expVal > 0 THEN
        j := 0;
        WHILE j # expVal DO mantissa := mantissa * 10.0; INC(j) END
      ELSIF expVal < 0 THEN
        j := 0;
        WHILE j # -expVal DO mantissa := mantissa / 10.0; INC(j) END
      END;
      IF neg THEN mantissa := -mantissa END;
      x := mantissa;
      IF Done & (ch <= ' ') THEN Take(ch) END
    END
  END
END Real;

PROCEDURE LongReal*(VAR x: LONGREAL); (**%RU:ДлинВещ,знач%LV:GaraisReālais,vērt*)
VAR r: REAL;
BEGIN
  Real(r);
  x := SYSTEM.VAL(LONGREAL, r)
END LongReal;

PROCEDURE Line*(VAR s: ARRAY OF CHAR); (**%RU:Линия,строка%LV:Rinda,rinda*)
VAR ch: CHAR; (**%RU:симв%LV:sim*)
    j, maxJ: INTEGER; (**%RU:максЖ,же%LV:maksJ,j*)
BEGIN
  IF Done THEN
    j := 0; maxJ := LEN(s) - 1;
    Peek(ch);
    WHILE Done & (ch # 0AX) DO
      Take(ch);
      IF (ch # 0DX) & (j < maxJ) THEN s[j] := ch; INC(j) END;
      Peek(ch)
    END;
    IF Done THEN Take(ch) END;
    s[j] := 0X
  END
END Line;

PROCEDURE Name*(VAR name: ARRAY OF CHAR); (**%RU:Имя,имя%LV:Vārds,vārds*)
VAR ch: CHAR; (**%RU:симв%LV:sim*)
    j, maxJ: INTEGER; (**%RU:максЖ,же%LV:maksJ,j*)
BEGIN
  IF Done THEN
    j := 0; maxJ := LEN(name) - 1;
    Peek(ch);
    WHILE Done & (ch <= ' ') DO Take(ch); Peek(ch) END;
    WHILE Done & (ch > ' ') DO
      IF j < maxJ THEN name[j] := ch; INC(j) END;
      Take(ch); Peek(ch)
    END;
    IF j <= maxJ THEN name[j] := 0X ELSE name[maxJ] := 0X END
  END
END Name;

PROCEDURE String*(VAR str: ARRAY OF CHAR); (**%RU:Строка,строка%LV:Leksēma,virkne*)
VAR ch, quote: CHAR; (**%RU:кав,симв%LV:pē,sim*)
    j, maxJ: INTEGER; (**%RU:максЖ,же%LV:maksJ,j*)
BEGIN
  IF Done THEN
    j := 0; maxJ := LEN(str) - 1;
    Peek(ch);
    WHILE Done & (ch <= ' ') DO Take(ch); Peek(ch) END;
    IF (ch # '"') & (ch # "'") THEN Done := FALSE
    ELSE
      quote := ch; Take(ch);
      Peek(ch);
      WHILE Done & (ch # quote) DO
        Take(ch);
        IF j # maxJ THEN str[j] := ch; INC(j) END;
        Peek(ch)
      END;
      IF Done THEN Take(ch) END;
      IF j <= maxJ THEN str[j] := 0X ELSE str[maxJ] := 0X END
    END
  END
END String;

BEGIN
  Done := TRUE; bufLen := 0
END In.
