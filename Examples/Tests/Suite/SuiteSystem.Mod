MODULE SuiteSystem;
(* SYSTEM.SVC and SYSTEM.ADR / ADRINT smoke tests. *)
IMPORT SYSTEM, Out;

VAR
  b: BYTE;
  fixed: ARRAY 8 OF BYTE;
  scalar: BYTE;
  diff: LONGINT;
  a, adrB: SYSTEM.ADRINT;
  li: LONGINT;
  i: INTEGER;

PROCEDURE TestOpen(VAR arr: ARRAY OF BYTE);
BEGIN
  IF SYSTEM.ADR(arr) = SYSTEM.ADR(arr[0]) THEN
    Out.String('open: ADR(a) = ADR(a[0]) -- OK')
  ELSE
    Out.String('open: MISMATCH')
  END;
  Out.Ln
END TestOpen;

PROCEDURE SvcPart;
VAR r: LONGINT;
BEGIN
  b := 48;
  r := SYSTEM.SVC(4, 1, SYSTEM.ADR(b), 1)
END SvcPart;

PROCEDURE MemPart;
VAR
  buf: ARRAY 32 OF BYTE;
  i: INTEGER;
  b: BYTE;
  res: INTEGER;
  s: SET;
  adr, adr2, src, dst: SYSTEM.ADRINT;
BEGIN
  buf[0] := 0; buf[1] := 0; buf[2] := 0; buf[3] := 0;
  buf[4] := 0; buf[5] := 0; buf[6] := 0; buf[7] := 0;
  adr := SYSTEM.ADR(buf[0]);
  i := 0DEADBEEFH;
  SYSTEM.PUT(adr, i);
  i := 0;
  SYSTEM.GET(adr, i);
  IF i = SYSTEM.VAL(INTEGER, 0DEADBEEFH) THEN Out.String('mem: PUT/GET INTEGER -- OK')
  ELSE Out.String('mem: PUT/GET INTEGER FAIL')
  END;
  Out.Ln;
  b := 0;
  adr2 := SYSTEM.ADR(buf[4]);
  SYSTEM.PUT(adr2, 0FEH);
  SYSTEM.GET(adr2, b);
  IF b = 0FEH THEN Out.String('mem: PUT/GET BYTE -- OK')
  ELSE Out.String('mem: PUT/GET BYTE FAIL')
  END;
  Out.Ln;
  IF SYSTEM.BIT(adr, 0) THEN Out.String('mem: BIT0 set -- OK')
  ELSE Out.String('mem: BIT0 clear')
  END;
  Out.Ln;
  IF SYSTEM.BIT(adr, 31) THEN Out.String('mem: BIT31 set -- OK')
  ELSE Out.String('mem: BIT31 FAIL')
  END;
  Out.Ln;
  s := {};
  SYSTEM.GET(adr, s);
  IF 0 IN s THEN Out.String('mem: GET SET -- OK')
  ELSE Out.String('mem: GET SET FAIL')
  END;
  Out.Ln;
  buf[8] := 11; buf[9] := 22; buf[10] := 33; buf[11] := 44;
  buf[12] := 55; buf[13] := 66; buf[14] := 77; buf[15] := 88;
  src := SYSTEM.ADR(buf[8]);
  dst := SYSTEM.ADR(buf[0]);
  SYSTEM.COPY(src, dst, 8);
  SYSTEM.GET(dst, b);
  IF ORD(b) = 11 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  adr2 := SYSTEM.ADR(buf[3]);
  SYSTEM.GET(adr2, b);
  IF ORD(b) = 44 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  adr2 := SYSTEM.ADR(buf[4]);
  SYSTEM.GET(adr2, b);
  IF ORD(b) = 55 THEN res := 1 ELSE res := 0 END;
  Out.Int(res, 0); Out.Ln;
  FOR i := 0 TO 31 DO buf[i] := i + 10 END;
  src := SYSTEM.ADR(buf[0]);
  dst := SYSTEM.ADR(buf[2]);
  SYSTEM.COPY(src, dst, 16);
  IF (buf[0] = 10) & (buf[1] = 11) & (buf[2] = 10) & (buf[9] = 17)
      & (buf[10] = 18) & (buf[17] = 25) THEN
    Out.String('mem: COPY overlap -- OK')
  ELSE
    Out.String('mem: COPY overlap FAIL')
  END;
  Out.Ln
END MemPart;

PROCEDURE AdrPart;
BEGIN
  scalar := 42;
  fixed[0] := 1; fixed[1] := 2; fixed[7] := 99;

  diff := SYSTEM.ADR(fixed) - SYSTEM.ADR(fixed[0]);
  IF diff = 0 THEN Out.String('fixed: ADR(fixed) = ADR(fixed[0]) -- OK')
  ELSE Out.String('fixed: MISMATCH')
  END;
  Out.Ln;

  diff := SYSTEM.ADR(fixed[1]) - SYSTEM.ADR(fixed[0]);
  IF diff = 1 THEN Out.String('fixed: ADR(fixed[1]) - ADR(fixed[0]) = 1 -- OK')
  ELSE Out.String('fixed: BAD STRIDE'); Out.Int(diff, 0)
  END;
  Out.Ln;

  IF SYSTEM.ADR(scalar) # 0 THEN Out.String('scalar: ADR # 0 -- OK')
  ELSE Out.String('scalar: ADR = 0')
  END;
  Out.Ln;

  TestOpen(fixed);

  a := SYSTEM.ADR(scalar);
  adrB := SYSTEM.ADR(fixed);

  li := a;
  a := li;
  IF a = SYSTEM.ADR(scalar) THEN Out.String('adrint: assign LONGINT round-trip -- OK')
  ELSE Out.String('adrint: round-trip MISMATCH')
  END;
  Out.Ln;

  IF a # adrB THEN Out.String('adrint: two distinct addrs differ -- OK')
  ELSE Out.String('adrint: distinct addrs collapsed')
  END;
  Out.Ln;

  IF SYSTEM.VAL(BYTE, 300) = 44 THEN Out.String('val: BYTE trunc -- OK')
  ELSE Out.String('val: BYTE trunc FAIL')
  END;
  Out.Ln;

  IF SYSTEM.VAL(LONGINT, -1) = -1 THEN Out.String('val: LONGINT sign -- OK')
  ELSE Out.String('val: LONGINT sign FAIL')
  END;
  Out.Ln;

  i := SHORT(a);
  IF LONG(i) = a - (a DIV 100000000H) * 100000000H THEN
    Out.String('adrint: SHORT preserves low 32 bits -- OK')
  ELSE
    Out.String('adrint: SHORT mismatch')
  END;
  Out.Ln;

  IF LONG(a) = a THEN Out.String('adrint: LONG is value-preserving -- OK')
  ELSE Out.String('adrint: LONG mismatch')
  END;
  Out.Ln
END AdrPart;

PROCEDURE DivModPart;
VAR q, r: INTEGER;
BEGIN
  q := SYSTEM.DIV(-7, 3);
  r := SYSTEM.MOD(-7, 3);
  IF (q = -2) & (r = -1) THEN Out.String('sys: DIV/MOD trunc -- OK')
  ELSE Out.String('sys: DIV/MOD trunc FAIL')
  END;
  Out.Ln;
  q := (-7) DIV 3;
  r := (-7) MOD 3;
  IF (q = -3) & (r = 2) THEN Out.String('sys: DIV/MOD floor -- OK')
  ELSE Out.String('sys: DIV/MOD floor FAIL')
  END;
  Out.Ln;
  q := -7 DIV 3;
  IF q = -2 THEN Out.String('sys: DIV unary prec -- OK')
  ELSE Out.String('sys: DIV unary prec FAIL')
  END;
  Out.Ln
END DivModPart;

PROCEDURE PackUnpkPart;
VAR x: REAL; n: INTEGER;
BEGIN
  x := 12.0;
  SYSTEM.UNPK(x, n);
  SYSTEM.PACK(x, 3);
  IF x = 12.0 THEN Out.String('sys: UNPK 12 -- OK')
  ELSE Out.String('sys: UNPK 12 FAIL')
  END;
  Out.Ln;
  x := 1.5;
  SYSTEM.PACK(x, 3);
  IF x = 12.0 THEN Out.String('sys: PACK 1.5 -- OK')
  ELSE Out.String('sys: PACK 1.5 FAIL')
  END;
  Out.Ln;
  x := 6.0;
  SYSTEM.UNPK(x, n);
  SYSTEM.PACK(x, n);
  IF x = 6.0 THEN Out.String('sys: PACK/UNPK round -- OK')
  ELSE Out.String('sys: PACK/UNPK round FAIL')
  END;
  Out.Ln;
  x := 6.0;
  SYSTEM.PACK(x, -2);
  IF x = 1.5 THEN Out.String('sys: PACK neg exp -- OK')
  ELSE Out.String('sys: PACK neg exp FAIL')
  END;
  Out.Ln;
END PackUnpkPart;

PROCEDURE FlagPart;
VAR a, b, r: INTEGER;
BEGIN
  a := 0FFFFFFFFH;
  b := 1;
  r := SYSTEM.ADC(a, b);
  IF SYSTEM.COND(2) THEN Out.String('flag: ADC carry -- OK')
  ELSE Out.String('flag: ADC carry FAIL')
  END;
  Out.Ln;
  IF r = 0 THEN Out.String('flag: ADC sum -- OK')
  ELSE Out.String('flag: ADC sum FAIL')
  END;
  Out.Ln;
  r := SYSTEM.ADC(a, b);
  IF SYSTEM.COND(2) THEN r := SYSTEM.ADC(0, 1) END;
  IF r = 2 THEN Out.String('flag: ADC chain -- OK')
  ELSE Out.String('flag: ADC chain FAIL')
  END;
  Out.Ln;
  r := SYSTEM.ADC(0FFFFFFFFH, 1);
  IF SYSTEM.COND(2) THEN
    r := SYSTEM.SBC(0, 1);
    IF r = -1 THEN Out.String('flag: SBC -- OK')
    ELSE Out.String('flag: SBC FAIL')
    END;
    Out.Ln
  ELSE Out.String('flag: SBC carry miss')
  END;
  Out.Ln;
  a := 10000H;
  b := 10000H;
  r := SYSTEM.UML(a, b);
  IF r = 0 THEN Out.String('flag: UML -- OK')
  ELSE Out.String('flag: UML FAIL')
  END;
  Out.Ln;
  IF SYSTEM.COND(14) THEN Out.String('flag: COND AL -- OK')
  ELSE Out.String('flag: COND AL FAIL')
  END;
  Out.Ln;
  IF SYSTEM.COND(15) THEN Out.String('flag: COND NV -- FAIL')
  ELSE Out.String('flag: COND NV -- OK')
  END;
  Out.Ln
END FlagPart;

BEGIN
  SvcPart;
  MemPart;
  DivModPart;
  PackUnpkPart;
  FlagPart;
  AdrPart
END SuiteSystem.
