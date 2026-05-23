MODULE Utf8;

CONST
  replacementChar* = 0FFFDX;

  bmpBase = 10000H;
  hiSurrogate = 0D800H;
  loSurrogate = 0DC00H;

VAR
  Done*: BOOLEAN; (** TRUE if the last conversion completed *)

(** Returns UTF-8 sequence length by lead byte. *)
PROCEDURE SeqLen*(b: BYTE): INTEGER;
VAR n: INTEGER;
BEGIN
  IF    b < 80H  THEN n := 1
  ELSIF b < 0C0H THEN n := 1 (* lone continuation byte; bad input *)
  ELSIF b < 0E0H THEN n := 2
  ELSIF b < 0F0H THEN n := 3
  ELSE                n := 4
  END
RETURN n END SeqLen;

(** Encodes one CHAR into UTF-8.
    Returns the number of bytes written, or -1 on error. *)
PROCEDURE EncodeChar*(c: CHAR; VAR s: ARRAY OF BYTE; offset: INTEGER): INTEGER;
VAR cv, len: INTEGER;
BEGIN
  cv := ORD(c); Done := TRUE; len := 0;
  IF cv < 80H THEN
    IF offset < LEN(s) THEN s[offset] := cv; len := 1
    ELSE Done := FALSE
    END
  ELSIF cv < 800H THEN
    IF offset + 1 < LEN(s) THEN
      s[offset] := 0C0H + ASR(cv, 6);
      s[offset + 1] := 80H + (cv MOD 40H);
      len := 2
    ELSE Done := FALSE
    END
  ELSE
    IF offset + 2 < LEN(s) THEN
      s[offset] := 0E0H + ASR(cv, 12);
      s[offset + 1] := 80H + (ASR(cv, 6) MOD 40H);
      s[offset + 2] := 80H + (cv MOD 40H);
      len := 3
    ELSE Done := FALSE
    END
  END;
  IF ~Done THEN len := -1 END
RETURN len END EncodeChar;

(** Encodes a CHAR slice into UTF-8.
    Returns the number of bytes written, or -1 on error. *)
PROCEDURE Encode*(in: ARRAY OF CHAR; inOff, inLen: INTEGER;
                  VAR out: ARRAY OF BYTE; outOff, outLen: INTEGER): INTEGER;
VAR i, end, outStart, outEnd, cv, need: INTEGER;
    stop: BOOLEAN;
BEGIN
  Done := TRUE;
  i := inOff; end := inOff + inLen;
  outStart := outOff; outEnd := outOff + outLen;
  IF end > LEN(in) THEN end := LEN(in) END;
  IF outEnd > LEN(out) THEN outEnd := LEN(out) END;
  stop := FALSE;
  WHILE Done & ~stop & (i # end) DO
    IF in[i] = 0X THEN stop := TRUE
    ELSE
      cv := ORD(in[i]);
      IF cv < 80H THEN need := 1
      ELSIF cv < 800H THEN need := 2
      ELSE need := 3
      END;
      IF outOff + need > outEnd THEN
        Done := FALSE
      ELSE
        outOff := outOff + EncodeChar(in[i], out, outOff);
        IF Done THEN INC(i) END
      END
    END
  END;
  IF ~Done THEN outOff := -1 END
RETURN outOff - outStart END Encode;

(** Decodes one UTF-8 sequence. Returns bytes consumed, or -1 on error.
    `lo` is 0X unless a supplementary-plane pair was decoded. *)
PROCEDURE DecodeCharEx*(VAR s: ARRAY OF BYTE; offset: INTEGER;
                        VAR hi, lo: CHAR): INTEGER;
VAR b, b2, b3, b4, cp, max, n: INTEGER;
BEGIN
  max := LEN(s); Done := TRUE; hi := 0X; lo := 0X; n := 0;
  IF offset >= max THEN
    Done := FALSE; n := -1
  ELSE
    b := s[offset];
    IF b < 80H THEN
      n := 1; hi := CHR(b)
    ELSIF b < 0C0H THEN
      Done := FALSE; n := -1; hi := replacementChar
    ELSIF b < 0E0H THEN
      IF offset + 1 < max THEN
        b2 := s[offset + 1]; n := 2;
        cp := (b - 0C0H) * 40H + b2 - 80H;
        hi := CHR(cp)
      ELSE Done := FALSE; n := -1; hi := replacementChar
      END
    ELSIF b < 0F0H THEN
      IF offset + 2 < max THEN
        b2 := s[offset + 1]; b3 := s[offset + 2]; n := 3;
        cp := (b - 0E0H) * 1000H + (b2 - 80H) * 40H + b3 - 80H;
        hi := CHR(cp)
      ELSE Done := FALSE; n := -1; hi := replacementChar
      END
    ELSE
      IF offset + 3 < max THEN
        b2 := s[offset + 1]; b3 := s[offset + 2]; b4 := s[offset + 3];
        n := 4;
        cp := (b - 0F0H) * 40000H + (b2 - 80H) * 1000H
            + (b3 - 80H) * 40H + b4 - 80H;
        cp := cp - bmpBase;
        hi := CHR(ASR(cp, 10) + hiSurrogate);
        lo := CHR(cp MOD 400H + loSurrogate)
      ELSE Done := FALSE; n := -1; hi := replacementChar
      END
    END
  END
RETURN n END DecodeCharEx;

(** Decodes one UTF-8 sequence; supplementary-plane input becomes 0FFFDX. *)
PROCEDURE DecodeChar*(VAR s: ARRAY OF BYTE; offset: INTEGER): CHAR;
VAR hi, lo: CHAR; n: INTEGER;
BEGIN
  n := DecodeCharEx(s, offset, hi, lo);
  IF (n > 0) & (lo # 0X) THEN hi := replacementChar END
RETURN hi END DecodeChar;

(** Decodes UTF-8 bytes into CHARs. *)
PROCEDURE Decode*(VAR in: ARRAY OF BYTE; inOff, inLen: INTEGER;
                  VAR out: ARRAY OF CHAR; outOff, outLen: INTEGER): INTEGER;
VAR i, o, outStart, end, outEnd, n: INTEGER;
    hi, lo: CHAR;
    stop: BOOLEAN;
BEGIN
  Done := TRUE; stop := FALSE;
  i := inOff; o := outOff;
  outStart := outOff;
  end := inOff + inLen;
  outEnd := outOff + outLen - 1;
  IF end > LEN(in) THEN end := LEN(in) END;
  IF outEnd >= LEN(out) THEN outEnd := LEN(out) - 1 END;
  WHILE ~stop DO
    IF i >= end THEN stop := TRUE
    ELSIF o >= outEnd THEN stop := TRUE
    ELSIF in[i] = 0 THEN stop := TRUE
    ELSE
      n := DecodeCharEx(in, i, hi, lo);
      IF n <= 0 THEN Done := FALSE; stop := TRUE
      ELSIF (lo # 0X) & (o + 1 >= outEnd) THEN stop := TRUE
      ELSE
        out[o] := hi; INC(o);
        IF lo # 0X THEN out[o] := lo; INC(o) END;
        i := i + n
      END
    END
  END;
  out[o] := 0X
RETURN o - outStart END Decode;

BEGIN
  Done := TRUE
END Utf8.
