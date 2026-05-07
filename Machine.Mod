MODULE Machine;
IMPORT Out, Lang, Platform, Utf8, Strings, SYSTEM;

TYPE
  LONGINT* = SYSTEM.INT64;
  LONGREAL* = REAL; (*!FIXME*)
  SHORTCHAR = Utf8.SHORTCHAR;

VAR
  maxLongInt*, minLongInt*: LONGINT;
  outDir*, outExe*: ARRAY 256 OF CHAR;

(** Run a command in the OS. For chmod and signing the executable. *)
PROCEDURE Exec*(command: ARRAY OF CHAR): INTEGER;
VAR z: ARRAY 4096 OF SHORTCHAR;
BEGIN
  Utf8.Encode(command, z);
RETURN Platform.System(z) END Exec;

(** Gets localized error text by error code. *)
PROCEDURE GetErrorText*(n: INTEGER; VAR s: ARRAY OF CHAR);
BEGIN
  Lang.GetErrorText(n, s);
  IF s = '' THEN s := 'Unknown error' END
END GetErrorText;

(** Outputs compiler error: file:line:col: error: #N text *)
PROCEDURE Mark*(fname: ARRAY OF CHAR; line, col, errCode: INTEGER);
VAR s: ARRAY 256 OF CHAR;
BEGIN
  Out.String(fname); Out.Char(':');
  Out.Int(line, 0); Out.Char(':'); Out.Int(col, 0);
  Out.String(': error: #'); Out.Int(errCode, 0); Out.Char(' ');
  GetErrorText(errCode, s); Out.String(s); Out.Ln
END Mark;

(** Outputs localized compiler message (no newline). *)
PROCEDURE Write*(msg: INTEGER);
VAR s: ARRAY 80 OF CHAR;
BEGIN
  Lang.GetCompilerText(msg, s);
  Out.String(s)
END Write;

(** Outputs localized compiler message with newline. *)
PROCEDURE WriteLn*(msg: INTEGER);
BEGIN
  Write(msg); Out.Ln
END WriteLn;

(** Outputs localized compiler message with a string parameter: text s *)
PROCEDURE WriteS*(msg: INTEGER; s: ARRAY OF CHAR);
BEGIN
  Write(msg); Out.Char(' '); Out.String(s); Out.Ln
END WriteS;

(** Outputs: msg1 s msg2. E.g. "Module Example has been compiled." *)
PROCEDURE WriteS2*(msg1: INTEGER; s: ARRAY OF CHAR; msg2: INTEGER);
BEGIN
  Write(msg1); Out.Char(' '); Out.String(s);
  Out.Char(' '); WriteLn(msg2)
END WriteS2;

(** Outputs compiler error: error: #N text *)
PROCEDURE WriteError*(msg: INTEGER);
VAR s: ARRAY 80 OF CHAR;
BEGIN
  Lang.GetCompilerText(msg, s);
  Out.String('error: #'); Out.Int(msg, 0);
  Out.Char(' '); Out.String(s); Out.Ln
END WriteError;

(** Outputs compiler error with a string parameter: error: #N text "s". *)
PROCEDURE WriteErrorS*(msg: INTEGER; s: ARRAY OF CHAR);
VAR t: ARRAY 80 OF CHAR;
BEGIN
  Lang.GetCompilerText(msg, t);
  Out.String('error: #'); Out.Int(msg, 0);
  Out.Char(' '); Out.String(t);
  Out.String(' "'); Out.String(s); Out.String('".'); Out.Ln
END WriteErrorS;

(** Outputs compiler error with an integer parameter: error: #N text n. *)
PROCEDURE WriteErrorI*(msg, n: INTEGER);
VAR s: ARRAY 80 OF CHAR;
BEGIN
  Lang.GetCompilerText(msg, s);
  Out.String('error: #'); Out.Int(msg, 0);
  Out.Char(' '); Out.String(s);
  Out.Char(' '); Out.Int(n, 0); Out.Char('.'); Out.Ln
END WriteErrorI;

PROCEDURE SHORT*(x: LONGINT): INTEGER;
RETURN SYSTEM.VAL(INTEGER, x) END SHORT;

PROCEDURE LONG*(x: INTEGER): LONGINT;
RETURN SYSTEM.VAL(LONGINT, x) END LONG;

PROCEDURE Pow2L(n: INTEGER): LONGINT;
VAR r: LONGINT;
BEGIN
  r := SYSTEM.VAL(LONGINT, 1);
  WHILE n > 0 DO r := r * SYSTEM.VAL(LONGINT, 2); DEC(n) END
RETURN r END Pow2L;

PROCEDURE LSL64*(x: LONGINT; n: INTEGER): LONGINT;
BEGIN
  IF n >= 64 THEN x := SYSTEM.VAL(LONGINT, 0)
  ELSIF n > 0 THEN x := x * Pow2L(n)
  END
RETURN x END LSL64;

PROCEDURE ASR64*(x: LONGINT; n: INTEGER): LONGINT;
BEGIN
  IF n >= 64 THEN
    IF x < SYSTEM.VAL(LONGINT, 0) THEN x := SYSTEM.VAL(LONGINT, -1)
    ELSE x := SYSTEM.VAL(LONGINT, 0)
    END
  ELSIF n > 0 THEN x := x DIV Pow2L(n)
  END
RETURN x END ASR64;

PROCEDURE ROR64*(x: LONGINT; n: INTEGER): LONGINT;
VAR i: INTEGER;
  bit: LONGINT;
  one, zero: LONGINT;
BEGIN
  one := SYSTEM.VAL(LONGINT, 1);
  zero := SYSTEM.VAL(LONGINT, 0);
  n := n MOD 64;
  FOR i := 1 TO n DO
    bit := x - (x DIV SYSTEM.VAL(LONGINT, 2)) * SYSTEM.VAL(LONGINT, 2);
    x := x DIV SYSTEM.VAL(LONGINT, 2);
    IF x < zero THEN x := x + Pow2L(63) END;
    IF bit # zero THEN x := x + Pow2L(63) END
  END
RETURN x END ROR64;

PROCEDURE SetOutDir*(path: ARRAY OF CHAR);
VAR n, i, last: INTEGER;
BEGIN
  n := Strings.Length(path);
  IF (n > 0) & (path[n - 1] = '/') THEN
    (* Directory mode: -o dir/ *)
    Strings.Copy(path, outDir);
    outExe := ''
  ELSIF n > 0 THEN
    (* Filename mode: -o name or -o dir/name *)
    last := -1; i := 0;
    WHILE i < n DO
      IF path[i] = '/' THEN last := i END;
      INC(i)
    END;
    IF last >= 0 THEN
      Strings.Copy(path, outDir);
      outDir[last + 1] := 0X
    ELSE
      outDir := ''
    END;
    Strings.Copy(path, outExe)
  END
END SetOutDir;

BEGIN
  maxLongInt := LSL64(LONG(7FFFFFFFH), 32) + LONG(7FFFFFFFH) * 2 + 1;
  minLongInt := -maxLongInt - 1;
  outDir := '';
  outExe := ''
END Machine.
