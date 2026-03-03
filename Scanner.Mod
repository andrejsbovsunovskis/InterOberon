MODULE Scanner;
IMPORT Files, Out, E := ErrorMsg, Lang, M := Machine;

CONST
  (** Symbols **)
  null       = 0;  (** Bad character *)
  times*     = 1;  (** *   *)
  div*       = 3;  (** DIV *)
  mod*       = 4;  (** MOD *)
  and*       = 5;  (** &   *)
  plus*      = 6;  (** +   *)
  minus*     = 7;  (** -   *)
  or*        = 8;  (** OR  *)
  eql*       = 9;  (** =   *)
  neq*       = 10; (** #   *)
  lss*       = 11; (** <   *)
  leq*       = 12; (** <=  *)
  gtr*       = 13; (** >   *)
  geq*       = 14; (** >=  *)
  period*    = 18; (** .   *)
(*char*      = 20;*)
  int*       = 21;
  false*     = 23; (** FALSE *)
  true*      = 24; (** TRUE  *)
  string*    = 26;
  not*       = 27; (** ~ *)
  lparen*    = 28; (** ( *)
  ident*     = 31;
  if*        = 32;
  while*     = 34;
  repeat*    = 35;
  comma*     = 40;
  colon*     = 41;
  becomes*   = 42; (** := *)
  rparen*    = 44; (** )  *)
  then*      = 47;
  do*        = 49;
  semicol*   = 52;
  end*       = 53;
  else*      = 55;
  elsif*     = 56;
  until*     = 57;
(*const*     = 63;*)
  var*       = 65; (** VAR *)
  begin*     = 67;
  import*    = 68;
  module*    = 69;
  eot        = 70; (** End of text *)

  (** - **)
  maxInt* = 2147483647;
  minInt* = -maxInt - 1;
  maxTrans*    = 8;    (** Max translation entries in a comment *)
  maxLangLen*  = 5;    (** Max length of a language code *)
  maxTransLen* = 2048; (** Max length of a translation string *)

VAR
  moduleFname: ARRAY 128 OF CHAR;
  r: Files.Rider;
  line, col: INTEGER;
  nextLine: BOOLEAN; (** Used in Read *)

  id*: ARRAY 64 OF CHAR;    (** When sym = ident *)
  len*: INTEGER;            (** When sym = ident or string *)
  ival*: INTEGER;           (** When sym = int *)
  sval*: ARRAY 256 OF CHAR; (** When sym = string *)

  ch: CHAR; (* Used in Get *)

  error*: BOOLEAN; (* FALSE if ok *)
  errPos: INTEGER; (* Position of last error *)

  transCount*: INTEGER;
  transLang*: ARRAY maxTrans, maxLangLen + 1 OF CHAR;
  transNames*: ARRAY maxTrans, maxTransLen + 1 OF CHAR;

PROCEDURE Read;
BEGIN
  Files.ReadChar(r, ch);
  IF r.eof THEN ch := 0X
  ELSIF nextLine THEN
    INC(line);
    col := 1;
    nextLine := FALSE
  ELSE
    INC(col)
  END;
  IF ch = 0AX THEN nextLine := TRUE END
END Read;

PROCEDURE Rewind*;
BEGIN
  Files.Set(r, Files.Base(r), 0);
  line := 1;
  col := 0;
  nextLine := FALSE;
  error := FALSE;
  errPos := -10;
  Read
END Rewind;

PROCEDURE Load*(fname: ARRAY OF CHAR): BOOLEAN;
VAR F: Files.File;
BEGIN
  moduleFname := fname;
  F := Files.Old(fname);
  IF F # NIL THEN Files.Set(r, F, 0); Rewind END
RETURN F # NIL END Load;

PROCEDURE Mark*(errCode: INTEGER);
VAR pos: INTEGER;
BEGIN
  error := TRUE; pos := Files.Pos(r);
  IF pos > errPos + 4 THEN
    errPos := pos;
    M.Mark(moduleFname, line, col, errCode)
  END
END Mark;

PROCEDURE LatinToLower(ch: CHAR): CHAR;
BEGIN
  IF ('A' <= ch) & (ch <= 'Z') THEN
    ch := CHR(ORD(ch) + (ORD('a') - ORD('A')))
  END
RETURN ch END LatinToLower;

PROCEDURE IsLatin(c: CHAR): BOOLEAN;
RETURN ( 'a' <= c) & (c <=  'z') OR
       ( 'A' <= c) & (c <=  'Z')
END IsLatin;

PROCEDURE IsLetter(c: CHAR): BOOLEAN;
RETURN ( 'a' <= c) & (c <=  'z') OR
       ( 'A' <= c) & (c <=  'Z') OR
       (0C0X <= c) & (c <= 2AFX) & ~((1C0X <= c) & (c <= 1C3X)) &
         (c # 0D7X) & (c # 0F7X) OR (* Latin *)
       ( 388X <= c) & (c <=  3FFX) OR (* Greek *)
       ( 400X <= c) & (c <=  481X) OR (* Cyrillic *)
       ( 48AX <= c) & (c <=  52FX) OR (* Cyrillic Extended *)
       ( 531X <= c) & (c <=  556X) OR (* Armenian *)
       ( 560X <= c) & (c <=  588X) OR (* Armenian *)
       ( 5D0X <= c) & (c <=  5EAX) OR (* Hebrew *)
       ( 710X <= c) & (c <=  74FX) OR (* Sirian *)
       (10A0X <= c) & (c <= 10FFX)    (* Georgian *)
END IsLetter;

(** Skips a possibly nested comment. Begins on ch = '*' after '(',
    ends with a character after ')'.
    Detects translation comments of the form
    "( **%XX:name1,name2%YY:name1,name2* )"
    and stores translations in transLang/transNames. *)
PROCEDURE Comment;
VAR end, trans: BOOLEAN;
  i, depth: INTEGER;
BEGIN
  Read; (* Skip the first '*' after '(' *)
  trans := FALSE;
  end := FALSE;
  IF ch = '*' THEN
    Read;
    IF ch = '%' THEN
      (* Translation comment ( **%XX:name...* ) *)
      trans := TRUE;
      transCount := 0;
      WHILE (ch = '%') & (transCount < maxTrans) DO
        Read; (* skip % *)
        i := 0;
        WHILE (ch # ':') & (ch # 0X) & (ch # '*') DO
          IF ~IsLatin(ch) OR (i = maxLangLen) THEN
            Mark(E.badTransLang)
          ELSE
            transLang[transCount, i] := LatinToLower(ch);
            INC(i)
          END;
          Read
        END;
        transLang[transCount, i] := 0X;
        IF ch = ':' THEN Read ELSE Mark(E.expColonTrans) END;
        i := 0;
        WHILE (ch # '%') & (ch # '*') & (ch # 0X) DO
          IF IsLetter(ch) OR (ch = ',') THEN
            IF i # maxTransLen THEN transNames[transCount, i] := ch; INC(i)
            ELSE Mark(E.longTransName)
            END
          ELSE Mark(E.badTransName)
          END;
          Read
        END;
        transNames[transCount, i] := 0X;
        INC(transCount)
      END;

      (* Skip to end of translation comment *)
      REPEAT
        IF ch = '*' THEN Read;
          IF ch = ')' THEN Read; end := TRUE END
        ELSIF ch = 0X THEN Mark(E.commentNotClosed); end := TRUE
        ELSE Read
        END
      UNTIL end

    ELSIF ch = ')' THEN
      Read; (* Empty ( ** ) comment *)
      end := TRUE
    END
  END;
  IF ~trans & ~end THEN
    (* Regular comment — iterative nesting via depth counter *)
    depth := 1;
    REPEAT
      IF ch = '(' THEN 
        Read;
        IF ch = '*' THEN INC(depth); Read END
      ELSIF ch = '*' THEN
        Read;
        IF ch = ')' THEN DEC(depth); Read END
      ELSIF ch = 0X THEN Mark(E.commentNotClosed); depth := 0
      ELSE Read
      END
    UNTIL depth = 0
  END
END Comment;

PROCEDURE Get*(VAR sym: INTEGER);
VAR quote: CHAR;
  marked: BOOLEAN;
  n: INTEGER;
  kw: ARRAY 32 OF CHAR;
BEGIN
  transCount := 0;
  REPEAT
    (* Skip whitespaces *)
    WHILE (ch # 0X) & (ch <= ' ') DO Read END;

    IF ch = 0X THEN
      sym := eot
    ELSIF ch = ':' THEN Read;
      IF ch = '=' THEN sym := becomes; Read ELSE sym := colon END
    ELSIF ch = '=' THEN sym := eql; Read
    ELSIF ch = '#' THEN sym := neq; Read
    ELSIF ch = '<' THEN Read;
      IF ch = '=' THEN sym := leq; Read ELSE sym := lss END
    ELSIF ch = '>' THEN Read;
      IF ch = '=' THEN sym := geq; Read ELSE sym := gtr END
    ELSIF ch = ';' THEN sym := semicol; Read
    ELSIF ch = '.' THEN sym := period; Read
    ELSIF ch = ',' THEN sym := comma; Read
    ELSIF ch = '*' THEN sym := times; Read
    ELSIF ch = '+' THEN sym := plus; Read
    ELSIF ch = '-' THEN sym := minus; Read
    ELSIF ch = '(' THEN Read;
      IF ch = '*' THEN Comment; sym := null ELSE sym := lparen END
    ELSIF ch = ')' THEN sym := rparen; Read
    ELSIF ch = '&' THEN sym := and; Read
    ELSIF ch = '~' THEN sym := not; Read
    ELSIF (ch = '"') OR (ch = "'") THEN
      quote := ch;
      len := 0;
      marked := FALSE;
      Read;
      WHILE (ch # 0X) & (ch # quote) DO
        IF len < LEN(sval) - 1 THEN
          sval[len] := ch;
          INC(len)
        ELSIF ~marked THEN
          Mark(E.longString);
          marked := TRUE
        END;
        Read
      END;
      sval[len] := 0X;
      Read;
      sym := string
    ELSIF ('0' <= ch) & (ch <= '9') THEN
      ival := 0;
      REPEAT
        n := ORD(ch) - ORD('0');
        IF ival <= (maxInt - n) DIV 10 THEN ival := ival * 10 + n
        ELSE Mark(E.intOverflow)
        END;
        Read
      UNTIL ~(('0' <= ch) & (ch <= '9'));
      sym := int
    ELSIF IsLetter(ch) THEN
      len := 0;
      REPEAT
        IF len < LEN(id) - 1 THEN
          id[len] := ch;
          INC(len)
        END;
        Read
      UNTIL ~(IsLetter(ch) OR ('0' <= ch) & (ch <= '9'));
      id[len] := 0X;
      Lang.FindKeyword(id, kw);
      IF    kw = ''       THEN sym := ident
      ELSIF kw = 'MODULE' THEN sym := module
      ELSIF kw = 'END'    THEN sym := end
      ELSIF kw = 'BEGIN'  THEN sym := begin
      ELSIF kw = 'VAR'    THEN sym := var
      ELSIF kw = 'IMPORT' THEN sym := import
      ELSIF kw = 'DIV'    THEN sym := div
      ELSIF kw = 'MOD'    THEN sym := mod
      ELSIF kw = 'OR'     THEN sym := or
      ELSIF kw = 'FALSE'  THEN sym := false
      ELSIF kw = 'TRUE'   THEN sym := true
      ELSIF kw = 'IF'     THEN sym := if
      ELSIF kw = 'THEN'   THEN sym := then
      ELSIF kw = 'ELSIF'  THEN sym := elsif
      ELSIF kw = 'ELSE'   THEN sym := else
      ELSIF kw = 'WHILE'  THEN sym := while
      ELSIF kw = 'DO'     THEN sym := do
      ELSIF kw = 'REPEAT' THEN sym := repeat
      ELSIF kw = 'UNTIL'  THEN sym := until
      ELSE Mark(E.unknownKW)
      END
    ELSE sym := null; Read
    END
  UNTIL sym # null
END Get;

END Scanner.
