MODULE Kernel;
IMPORT SYSTEM;

CONST
  stderr = 2;
  sysWrite = 4;
  sysExit = 1;

PROCEDURE OutByte(b: BYTE);
BEGIN
  IF SYSTEM.SVC(sysWrite, stderr, SYSTEM.ADR(b), 1) = 0 THEN END
END OutByte;

PROCEDURE OutString(s: ARRAY OF CHAR);
VAR i, cv, t: INTEGER;
BEGIN
  i := 0;
  WHILE s[i] # 0X DO
    cv := ORD(s[i]);
    IF cv < 80H THEN OutByte(cv)
    ELSIF cv < 800H THEN
      t := cv DIV 40H + 0C0H; OutByte(t);
      t := cv MOD 40H + 80H; OutByte(t)
    ELSE
      t := cv DIV 1000H + 0E0H; OutByte(t);
      t := cv DIV 40H MOD 40H + 80H; OutByte(t);
      t := cv MOD 40H + 80H; OutByte(t)
    END;
    INC(i)
  END
END OutString;

PROCEDURE OutInt(n: INTEGER);
VAR buf: ARRAY 16 OF CHAR;
  i, d: INTEGER;
BEGIN
  IF n = 0 THEN OutByte(ORD('0'))
  ELSE
    IF n < 0 THEN OutByte(ORD('-')); n := -n END;
    i := 0;
    WHILE n # 0 DO
      d := n MOD 10;
      buf[i] := CHR(ORD('0') + d);
      n := n DIV 10;
      INC(i)
    END;
    WHILE i # 0 DO DEC(i); OutByte(ORD(buf[i])) END
  END
END OutInt;

PROCEDURE Assert*(mod, proc: ARRAY OF CHAR; line, n: INTEGER);
BEGIN
  IF n # 0 THEN
    OutString('ASSERT ');
    OutInt(n);
    OutString(' failed in ')
  ELSE
    OutString('ASSERT failed in ')
  END;
  OutString(mod);
  IF proc[0] # 0X THEN
    OutByte(2EH);
    OutString(proc)
  END;
  OutString(', line ');
  OutInt(line);
  OutByte(10);
  IF n # 0 THEN
    IF SYSTEM.SVC(sysExit, n, 0, 0) = 0 THEN END
  ELSE
    IF SYSTEM.SVC(sysExit, 1, 0, 0) = 0 THEN END
  END
END Assert;

END Kernel.
