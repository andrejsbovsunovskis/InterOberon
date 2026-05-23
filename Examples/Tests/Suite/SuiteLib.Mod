MODULE SuiteLib;
(* Lib/Utf8, Heap, and Platform smoke tests. *)
IMPORT Out, Utf8, Platform, Heap, SYSTEM;

VAR
  src: ARRAY 16 OF CHAR;
  buf: ARRAY 32 OF BYTE;
  back: ARRAY 16 OF CHAR;
  oneByte: ARRAY 4 OF BYTE;
  msg: ARRAY 64 OF CHAR;
  wbuf: ARRAY 16 OF BYTE;
  i, len, used: INTEGER;
  c, lo: CHAR;
  r: LONGINT;

PROCEDURE HeapPart;
VAR p, q: SYSTEM.ADRINT;
BEGIN
  p := Heap.Allocate(32);
  q := Heap.Allocate(32);
  IF p # q THEN Out.String('heap ok') ELSE Out.String('heap fail') END; Out.Ln
END HeapPart;

PROCEDURE WriteHiPart;
VAR s: ARRAY 8 OF CHAR;
BEGIN
  s[0] := CHR(70 + 2);
  s[1] := CHR(100 + 5);
  s[2] := 0X;
  Platform.WriteString(Platform.stdout, s, 0, 2)
END WriteHiPart;

PROCEDURE PlatWritePart;
VAR b: BYTE;
BEGIN
  b := 49;
  r := Platform.Write(Platform.stdout, b)
END PlatWritePart;

PROCEDURE Utf8Part;
BEGIN
  src[0] := 'A';
  src[1] := CHR(0410H);
  src[2] := CHR(20BDH);
  src[3] := 0X;

  Out.String('--- Encode/Decode ---'); Out.Ln;

  used := Utf8.Encode(src, 0, 3, buf, 0, LEN(buf));
  IF Utf8.Done THEN Out.String('Encode: Done = TRUE') ELSE Out.String('Encode: Done = FALSE') END;
  Out.Ln;

  Out.String('UTF-8 bytes:');
  i := 0;
  WHILE (i < LEN(buf)) & (i < 8) DO
    Out.String(' '); Out.Hex(buf[i], 2); INC(i)
  END;
  Out.Ln;

  used := Utf8.Decode(buf, 0, 6, back, 0, LEN(back));
  IF Utf8.Done THEN Out.String('Decode: Done = TRUE') ELSE Out.String('Decode: Done = FALSE') END;
  Out.Ln;

  Out.String('Decoded codepoints:');
  i := 0;
  WHILE (i < LEN(back)) & (back[i] # 0X) DO
    Out.String(' '); Out.Hex(ORD(back[i]), 4); INC(i)
  END;
  Out.Ln;

  Out.String('--- DecodeChar/EncodeChar ---'); Out.Ln;
  c := Utf8.DecodeChar(buf, 1);
  Out.String('decoded byte 1+: codepoint='); Out.Hex(ORD(c), 4); Out.Ln;
  len := Utf8.DecodeCharEx(buf, 1, c, lo);
  Out.String('DecodeCharEx bytes='); Out.Int(len, 0); Out.Ln;

  len := Utf8.EncodeChar(CHR(20ACH), oneByte, 0);
  Out.String('Euro single-char encoded len='); Out.Int(len, 0);
  Out.String(':');
  i := 0;
  WHILE i < len DO Out.String(' '); Out.Hex(oneByte[i], 2); INC(i) END;
  Out.Ln
END Utf8Part;

PROCEDURE PlatformPart;
BEGIN
  msg[0] := 'h'; msg[1] := 'i'; msg[2] := ' ';
  msg[3] := CHR(0410H); msg[4] := CHR(0420H);
  msg[5] := 0AX; msg[6] := 0X;
  Platform.WriteString(Platform.stdout, msg, 0, 6);

  wbuf[0] := ORD('A'); wbuf[1] := ORD('B'); wbuf[2] := ORD('C');
  wbuf[3] := 0AH;
  r := Platform.WriteBytes(Platform.stdout, wbuf, 0, 4)
END PlatformPart;

BEGIN
  Utf8Part;
  HeapPart;
  WriteHiPart;
  PlatWritePart;
  PlatformPart
END SuiteLib.
