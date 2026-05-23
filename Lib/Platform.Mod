MODULE Platform;
IMPORT SYSTEM, Utf8;

CONST
  stdin*  = 0;
  stdout* = 1;
  stderr* = 2;

  (** Darwin syscall numbers **)
  sysExit  = 1;
  sysRead  = 3;
  sysWrite = 4;

(** Write a single byte to the `fd`. *)
PROCEDURE Write*(fd: INTEGER; b: BYTE): INTEGER;
RETURN SYSTEM.SVC(sysWrite, fd, SYSTEM.ADR(b), 1) END Write;

(** Read a single byte from the `fd`. *)
PROCEDURE Read*(fd: INTEGER; VAR b: BYTE): INTEGER;
RETURN SYSTEM.SVC(sysRead, fd, SYSTEM.ADR(b), 1) END Read;

(** Read one character from `fd` (UTF-8 on the wire).
    Returns the number of CHARs produced (1 or 2), 0 on EOF,
    negative on error. `lo` is 0X for a single code unit. *)
PROCEDURE ReadCharEx*(fd: INTEGER; VAR hi, lo: CHAR): INTEGER;
VAR buf: ARRAY 4 OF BYTE;
    rb: INTEGER; b: BYTE;
    have, want, n: INTEGER;
    bad: BOOLEAN;
BEGIN
  bad := FALSE;
  rb := Read(fd, b);
  IF rb # 1 THEN
    IF rb < 0 THEN n := -1 ELSE n := 0 END;
    hi := 0X; lo := 0X
  ELSE
    buf[0] := b; have := 1;
    want := Utf8.SeqLen(b);
    WHILE (have < want) & ~bad DO
      rb := Read(fd, buf[have]);
      IF rb = 1 THEN INC(have) ELSE bad := TRUE END
    END;
    IF bad THEN
      n := -1; hi := Utf8.replacementChar; lo := 0X
    ELSE
      IF Utf8.DecodeCharEx(buf, 0, hi, lo) <= 0 THEN
        n := -1; hi := Utf8.replacementChar; lo := 0X
      ELSIF lo # 0X THEN n := 2
      ELSE n := 1
      END
    END
  END
RETURN n END ReadCharEx;

(** Read one CHAR from `fd.
   Non-BMP input becomes Utf8.replacementChar. *)
PROCEDURE ReadChar*(fd: INTEGER): CHAR;
VAR hi, lo: CHAR; n: INTEGER;
BEGIN
  n := ReadCharEx(fd, hi, lo);
  IF n # 1 THEN hi := 0X
  ELSIF lo # 0X THEN hi := Utf8.replacementChar
  END
RETURN hi END ReadChar;

(** Write bytes `buf[offset..offset+len-1]` to `fd`.
    Returns the number of bytes written, 0 on EOF, negative on error. *)
PROCEDURE WriteBytes*(fd: INTEGER; VAR buf: ARRAY OF BYTE;
                      offset, len: INTEGER): LONGINT;
VAR n: INTEGER; r: LONGINT;
BEGIN
  IF offset < 0 THEN offset := 0 END;
  n := len;
  IF offset + n > LEN(buf) THEN n := LEN(buf) - offset END;

  IF n <= 0 THEN
    r := 0
  ELSE
    r := SYSTEM.SVC(sysWrite, fd, SYSTEM.ADR(buf[offset]), n)
  END
RETURN r END WriteBytes;

(** Read up to `len` bytes into `buf[offset..offset+len-1]` from `fd`.
    Returns the number of bytes read, 0 on EOF, negative on error. *)
PROCEDURE ReadBytes*(fd: INTEGER; VAR buf: ARRAY OF BYTE;
                     offset, len: INTEGER): LONGINT;
VAR n: INTEGER; r: LONGINT;
BEGIN
  IF offset < 0 THEN offset := 0 END;
  n := len;
  IF offset + n > LEN(buf) THEN n := LEN(buf) - offset END;

  IF n <= 0 THEN
    r := 0
  ELSE
    r := SYSTEM.SVC(sysRead, fd, SYSTEM.ADR(buf[offset]), n)
  END
RETURN r END ReadBytes;

(** Write the CHAR slice `s[offset..offset+len-1]` to `fd`.
    Stops at the first 0X in the slice. *)
PROCEDURE WriteString*(fd: INTEGER; s: ARRAY OF CHAR;
                       offset, len: INTEGER);
VAR buf: ARRAY 16384 OF BYTE;
    outUsed: INTEGER;
    r: LONGINT;
BEGIN
  IF offset < 0 THEN offset := 0 END;
  outUsed := Utf8.Encode(s, offset, len, buf, 0, LEN(buf));
  IF outUsed > 0 THEN
    r := WriteBytes(fd, buf, 0, outUsed)
  END
END WriteString;

(** Read up to `len` CHARs into `s[offset..offset+len-1]`.
    Returns the number of CHARs actually read, 0 on EOF,
    negative on error. *)
PROCEDURE ReadString*(fd: INTEGER; VAR s: ARRAY OF CHAR;
                      offset, len: INTEGER): LONGINT;
VAR buf: ARRAY 4 OF BYTE;
    have, want, end: INTEGER;
    written, rb, result: LONGINT;
    hi, lo: CHAR;
    n: INTEGER;
    stop, kernelErr: BOOLEAN;
BEGIN
  written := 0; stop := FALSE; kernelErr := FALSE;
  end := offset + len;
  IF end > LEN(s) THEN end := LEN(s) END;
  WHILE ~stop & (offset < end) DO
    rb := SYSTEM.SVC(sysRead, fd, SYSTEM.ADR(buf[0]), 1);
    IF rb = 1 THEN
      have := 1;
      want := Utf8.SeqLen(buf[0]);
      WHILE ~stop & (have < want) DO
        rb := SYSTEM.SVC(sysRead, fd, SYSTEM.ADR(buf[have]), 1);
        IF rb = 1 THEN INC(have)
        ELSE
          IF rb < 0 THEN kernelErr := TRUE END;
          stop := TRUE
        END
      END;
      IF ~stop THEN
        n := Utf8.DecodeCharEx(buf, 0, hi, lo);
        IF n <= 0 THEN stop := TRUE
        ELSE
          s[offset] := hi; INC(offset); INC(written);
          IF (lo # 0X) & (offset < end) THEN
            s[offset] := lo; INC(offset); INC(written)
          END
        END
      END
    ELSE
      IF rb < 0 THEN kernelErr := TRUE END;
      stop := TRUE
    END
  END;
  IF kernelErr & (written = 0) THEN result := -1
  ELSE result := written
  END
RETURN result END ReadString;

PROCEDURE Exit*(code: INTEGER);
BEGIN
  IF SYSTEM.SVC(sysExit, code, 0, 0) = 0 THEN END
END Exit;

END Platform.
