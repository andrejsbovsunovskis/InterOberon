MODULE Strings; (**%RU:Строки%LV:Virknes*)
(** Operations on null-terminated character arrays (positions start at 0). *)

PROCEDURE Length*(s: ARRAY OF CHAR): INTEGER; (**%RU:Длина,с%LV:Garums,v*)
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE (i # LEN(s)) & (s[i] # 0X) DO INC(i) END
RETURN i END Length;

PROCEDURE Append*(extra: ARRAY OF CHAR; VAR dest: ARRAY OF CHAR); (**%RU:Дописать,доп,приёмник%LV:Pievienot,ekstra,mērķis*)
VAR n1, n2, i: INTEGER;
BEGIN
  n1 := Length(dest); n2 := Length(extra); i := 0;
  WHILE (i # n2) & (i + n1 < LEN(dest)) DO dest[i + n1] := extra[i]; INC(i) END;
  IF i + n1 < LEN(dest) THEN dest[i + n1] := 0X ELSE dest[LEN(dest) - 1] := 0X END
END Append;

PROCEDURE Insert*(source: ARRAY OF CHAR; pos: INTEGER; VAR dest: ARRAY OF CHAR); (**%RU:Вставить,источник,поз,приёмник%LV:Ievietot,avots,poz,mērķis*)
VAR n1, n2, len, i, j: INTEGER;
BEGIN
  n1 := Length(dest); n2 := Length(source); len := LEN(dest);
  IF pos > n1 THEN Append(source, dest)
  ELSE
    IF pos < 0 THEN pos := 0 END;
    IF pos + n2 < len THEN
      i := n1; j := i + n2;
      WHILE i >= pos DO
        IF j < len THEN dest[j] := dest[i] END;
        DEC(i); DEC(j)
      END
    END;
    i := 0; j := pos;
    WHILE (i # n2) & (j < len) DO dest[j] := source[i]; INC(i); INC(j) END;
    IF pos + n2 >= len THEN
      IF len # 0 THEN dest[len - 1] := 0X END
    END
  END
END Insert;

PROCEDURE Delete*(VAR s: ARRAY OF CHAR; pos, n: INTEGER); (**%RU:Удалить,строка,поз,число%LV:Dzēst,virkne,poz,skaits*)
VAR len, i: INTEGER;
BEGIN
  len := Length(s);
  IF pos < 0 THEN pos := 0 END;
  IF pos < len THEN
    IF pos + n < len THEN
      i := pos + n;
      WHILE i < len DO s[i - n] := s[i]; INC(i) END;
      IF i - n < LEN(s) THEN s[i - n] := 0X END
    ELSE s[pos] := 0X
    END
  END
END Delete;

PROCEDURE Replace*(source: ARRAY OF CHAR; pos: INTEGER; VAR dest: ARRAY OF CHAR); (**%RU:Заменить,источник,поз,приёмник%LV:Aizstāt,avots,poz,mērķis*)
BEGIN
  Delete(dest, pos, Length(source));
  Insert(source, pos, dest)
END Replace;

PROCEDURE Extract*(source: ARRAY OF CHAR; pos, n: INTEGER; VAR dest: ARRAY OF CHAR); (**%RU:Извлечь,источник,поз,число,приёмник%LV:Izvilkt,avots,poz,skaits,mērķis*)
VAR slen, i, cap, sp: INTEGER; ch: CHAR;
BEGIN
  slen := Length(source);
  IF pos < 0 THEN pos := 0 END;
  IF pos >= slen THEN dest[0] := 0X
  ELSE
    cap := LEN(dest) - 1;
    IF n > cap THEN n := cap END;
    sp := pos; i := 0;
    WHILE (i # n) & (sp < slen) DO
      ch := source[sp]; INC(sp);
      dest[i] := ch; INC(i);
      IF ch = 0X THEN i := n END
    END;
    IF i < LEN(dest) THEN dest[i] := 0X ELSE dest[LEN(dest) - 1] := 0X END
  END
END Extract;

PROCEDURE Copy*(src: ARRAY OF CHAR; VAR dst: ARRAY OF CHAR); (**%RU:Копировать,откуда,куда%LV:Kopēt,avots,kur*)
VAR i, len: INTEGER;
BEGIN
  IF LEN(src) < LEN(dst) THEN len := LEN(src) - 1 ELSE len := LEN(dst) - 1 END;
  i := 0;
  WHILE (i # len) & (src[i] # 0X) DO dst[i] := src[i]; INC(i) END;
  dst[i] := 0X
END Copy;

PROCEDURE Pos*(pattern, s: ARRAY OF CHAR; pos: INTEGER): INTEGER; (**%RU:Позиция,шаблон,строка,поз%LV:Pozīcija,paraugs,virkne,poz*)
VAR n1, n2, i, j, res, si, pi: INTEGER; found: BOOLEAN;
BEGIN
  n1 := Length(s); n2 := Length(pattern);
  IF n2 = 0 THEN res := 0
  ELSE
    IF pos < 0 THEN pos := 0 END;
    i := pos; found := FALSE;
    WHILE ~found & (i <= n1 - n2) DO
      IF s[i] = pattern[0] THEN
        si := i; pi := 0; j := 0;
        WHILE (j # n2) & (s[si] = pattern[pi]) DO
          INC(j); INC(si); INC(pi)
        END;
        IF j = n2 THEN found := TRUE; res := i END
      END;
      INC(i)
    END;
    IF ~found THEN res := -1 END
  END
RETURN res END Pos;

PROCEDURE Cap*(VAR s: ARRAY OF CHAR); (**%RU:ВерхнийРегистр,строка%LV:LielieBurti,virkne*)
VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE s[i] # 0X DO
    IF ('a' <= s[i]) & (s[i] <= 'z') THEN s[i] := CHR(ORD(s[i]) - 20H) END;
    INC(i)
  END
END Cap;

END Strings.
