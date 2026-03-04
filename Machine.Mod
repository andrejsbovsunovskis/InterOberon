MODULE Machine;
IMPORT Out, Lang, Platform, Utf8;

TYPE
  SHORTCHAR = Utf8.SHORTCHAR;

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

(** Outputs localized RISC message (no newline). *)
PROCEDURE Write*(msg: INTEGER);
VAR s: ARRAY 80 OF CHAR;
BEGIN
  Lang.GetRiscText(msg, s);
  Out.String(s)
END Write;

(** Outputs localized RISC message with newline. *)
PROCEDURE WriteLn*(msg: INTEGER);
BEGIN
  Write(msg); Out.Ln
END WriteLn;

(** Outputs localized RISC message with a string parameter: text s *)
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

(** Outputs RISC error: error: #N text *)
PROCEDURE WriteError*(msg: INTEGER);
VAR s: ARRAY 80 OF CHAR;
BEGIN
  Lang.GetRiscText(msg, s);
  Out.String('error: #'); Out.Int(msg, 0);
  Out.Char(' '); Out.String(s); Out.Ln
END WriteError;

(** Outputs RISC error with a string parameter: error: #N text "s". *)
PROCEDURE WriteErrorS*(msg: INTEGER; s: ARRAY OF CHAR);
VAR t: ARRAY 80 OF CHAR;
BEGIN
  Lang.GetRiscText(msg, t);
  Out.String('error: #'); Out.Int(msg, 0);
  Out.Char(' '); Out.String(t);
  Out.String(' "'); Out.String(s); Out.String('".'); Out.Ln
END WriteErrorS;

(** Outputs RISC error with an integer parameter: error: #N text n. *)
PROCEDURE WriteErrorI*(msg, n: INTEGER);
VAR s: ARRAY 80 OF CHAR;
BEGIN
  Lang.GetRiscText(msg, s);
  Out.String('error: #'); Out.Int(msg, 0);
  Out.Char(' '); Out.String(s);
  Out.Char(' '); Out.Int(n, 0); Out.Char('.'); Out.Ln
END WriteErrorI;

END Machine.
