(* Built-ins in IF: value/VAR params, locals, globals, literals, CONST.
   Covers ODD/ABS/ORD/CHR/LSL/ASR/ROR/FLOOR/FLT/SHORT/LONG/LEN. *)
MODULE BuiltinCond;
IMPORT Out;
CONST
  Ko = 9;
  Ke = 8;
  Kch = 'A';
  KordA = 65;
  KlslA = 3;
  KlslB = 2;
  Klslexp = 12;
VAR
  gI, gI2: INTEGER;
  gByte: BYTE;
  gShort: SHORTINT;
  gLong: LONGINT;
  gChar: CHAR;
  gBool: BOOLEAN;
  gSet: SET;
  gLs: LONGSET;
  gReal: REAL;
  gArr: ARRAY 5 OF INTEGER;
  gArr3: ARRAY 3 OF INTEGER;
  gRor: INTEGER;

PROCEDURE OddVar(VAR n: INTEGER);
BEGIN
  IF ODD(n) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END OddVar;

PROCEDURE OddVal(n: INTEGER);
BEGIN
  IF ODD(n) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END OddVal;

PROCEDURE AbsVar(VAR n: INTEGER);
BEGIN
  IF ABS(n) = 11 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END AbsVar;

PROCEDURE AbsVal(n: INTEGER);
BEGIN
  IF ABS(n) = 11 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END AbsVal;

PROCEDURE OrdFromVarChar(VAR c: CHAR);
BEGIN
  IF ORD(c) = 66 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END OrdFromVarChar;

PROCEDURE OrdVarBool(VAR b: BOOLEAN);
BEGIN
  IF ORD(b) = 0 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END OrdVarBool;

PROCEDURE OrdCharVal(c: CHAR);
BEGIN
  IF ORD(c) = 66 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END OrdCharVal;

PROCEDURE ChrVal(n: INTEGER);
BEGIN
  IF CHR(n) = 'C' THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END ChrVal;

PROCEDURE ChrFromVarInt(VAR n: INTEGER);
BEGIN
  IF CHR(n) = 'C' THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END ChrFromVarInt;

PROCEDURE LslVarSh(VAR a: INTEGER; b: INTEGER);
BEGIN
  IF LSL(a, b) = 40 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END LslVarSh;

PROCEDURE LslValPair(a, b: INTEGER);
BEGIN
  IF LSL(a, b) = 40 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END LslValPair;

PROCEDURE AsrVarSh(VAR a: INTEGER; b: INTEGER);
BEGIN
  IF ASR(a, b) = -4 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END AsrVarSh;

PROCEDURE RorVarSh(VAR a: INTEGER; b: INTEGER);
BEGIN
  IF ROR(a, b) = gRor THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END RorVarSh;

PROCEDURE FloorVar(VAR r: REAL);
BEGIN
  IF FLOOR(r) = 2 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END FloorVar;

PROCEDURE FltVar(VAR i: INTEGER);
BEGIN
  IF FLOOR(FLT(i)) = 7 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END FltVar;

PROCEDURE ShortVar(VAR li: LONGINT);
BEGIN
  IF SHORT(li) = 100 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END ShortVar;

PROCEDURE LenOpen(VAR a: ARRAY OF INTEGER);
BEGIN
  IF LEN(a) = 3 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END LenOpen;

PROCEDURE LocalBlock;
VAR
  locI, locI2: INTEGER;
  locByte: BYTE;
  locShort: SHORTINT;
  locChar: CHAR;
  locReal: REAL;
  locRor: INTEGER;
BEGIN
  locI := 7;
  IF ODD(locI) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  locI := -11;
  IF ABS(locI) = 11 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  locChar := 'B';
  IF ORD(locChar) = 66 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  locI := 67;
  IF CHR(locI) = 'C' THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  locI := 5;
  locI2 := 3;
  IF LSL(locI, locI2) = 40 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  locI := -16;
  locI2 := 2;
  IF ASR(locI, locI2) = -4 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  locI := 256;
  locI2 := 4;
  locRor := ROR(locI, locI2);
  IF ROR(locI, locI2) = locRor THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  locReal := 2.7;
  IF FLOOR(locReal) = 2 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  locI := 7;
  IF FLOOR(FLT(locI)) = 7 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  locByte := 9;
  IF ODD(locByte) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  locShort := -11;
  IF ABS(locShort) = 11 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END LocalBlock;

PROCEDURE LocalBlock2;
VAR
  locLong: LONGINT;
  locSet: SET;
  locLs: LONGSET;
BEGIN
  locLong := 100;
  IF SHORT(locLong) = 100 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  locSet := {1, 2};
  IF ORD(locSet) = 6 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  locLs := {};
  INCL(locLs, 5);
  IF ORD(locLs) = 32 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF SHORT(ORD(locLs)) = 32 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln
END LocalBlock2;

BEGIN
  gRor := ROR(256, 4);

  (* ODD: literal, CONST, global, value param, VAR param, BYTE *)
  IF ODD(7) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF ODD(Ko) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF ODD(Ke) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  gI := 11;
  IF ODD(gI) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  OddVal(11);
  OddVal(Ke);
  OddVar(gI);
  gByte := 7;
  IF ODD(gByte) THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* ABS: literal, global, value/VAR param, SHORTINT, LONGINT *)
  IF ABS(-11) = 11 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  gI := -11;
  IF ABS(gI) = 11 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  AbsVal(-11);
  AbsVar(gI);
  gShort := -11;
  IF ABS(gShort) = 11 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  gLong := -11;
  IF ABS(gLong) = 11 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* ORD: literal, CONST CHAR, global, value param, BOOL, SET *)
  IF ORD('B') = 66 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF ORD(Kch) = KordA THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  gChar := 'B';
  IF ORD(gChar) = 66 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  OrdCharVal('B');
  OrdFromVarChar(gChar);
  gBool := FALSE;
  OrdVarBool(gBool);
  IF ORD(TRUE) = 1 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF ORD(gBool) = 0 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  gSet := {1, 2};
  IF ORD(gSet) = 6 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* CHR ... *)
  IF CHR(67) = 'C' THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF CHR(ORD(Kch)) = Kch THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  gI := 67;
  IF CHR(gI) = 'C' THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  ChrVal(67);
  ChrFromVarInt(gI);
  gByte := 67;
  IF CHR(gByte) = 'C' THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF gChar = "B" THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* LSL / ASR / ROR *)
  IF LSL(3, 2) = 12 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF LSL(KlslA, KlslB) = Klslexp THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  gI := 3;
  gI2 := 2;
  IF LSL(gI, gI2) = 12 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  LslValPair(5, 3);
  gI := 5;
  LslVarSh(gI, 3);
  IF ASR(-16, 2) = -4 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  gI := -16;
  AsrVarSh(gI, 2);
  IF ROR(256, 4) = gRor THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  gI := 256;
  RorVarSh(gI, 4);

  (* FLOOR / FLT *)
  IF FLOOR(2.7) = 2 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  gReal := 2.7;
  IF FLOOR(gReal) = 2 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  FloorVar(gReal);
  IF FLOOR(FLT(7)) = 7 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  gI := 7;
  FltVar(gI);

  (* SHORT / LONG *)
  IF SHORT(LONG(SHORT(100))) = 100 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  gLong := 100;
  IF SHORT(gLong) = 100 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  ShortVar(gLong);
  LenOpen(gArr3);

  (* LEN: fixed array, literal & global *)
  IF LEN(gArr) = 5 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF LEN(gArr3) = 3 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  gI := LEN(gArr);
  IF gI = 5 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  (* LONGSET: ORD and SHORT(ORD) in IF *)
  gLs := {};
  INCL(gLs, 5);
  IF ORD(gLs) = 32 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;
  IF SHORT(ORD(gLs)) = 32 THEN Out.Int(1, 0) ELSE Out.Int(0, 0) END;
  Out.Ln;

  LocalBlock;
  LocalBlock2
END BuiltinCond.
