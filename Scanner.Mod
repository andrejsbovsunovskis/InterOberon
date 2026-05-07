MODULE Scanner;
IMPORT Files, Out, E := ErrorMsg, Lang, M := Machine;

CONST
  (** Symbols **)
  null       = 0;  (** Bad character *)
  times*     = 1;  (** *  *)
  rdiv*      = 2;  (** /  *)
  div*       = 3;
  mod*       = 4;
  and*       = 5;  (** &  *)
  plus*      = 6;  (** +  *)
  minus*     = 7;  (** -  *)
  or*        = 8;
  eql*       = 9;  (** =  *)
  neq*       = 10; (** #  *)
  lss*       = 11; (** <  *)
  leq*       = 12; (** <= *)
  gtr*       = 13; (** >  *)
  geq*       = 14; (** >= *)
  lbrak*     = 15; (** [  *)
  rbrak*     = 16; (** ]  *)
  period*    = 18; (** .  *)
  upto*      = 19; (** .. *)
  char*      = 20;
  int*       = 21;
  real*      = 22;
  false*     = 23;
  true*      = 24;
  string*    = 26;
  not*       = 27; (** ~ *)
  lparen*    = 28; (** ( *)
  lbrace*    = 29; (** { *)
  rbrace*    = 30; (** } *)
  ident*     = 31;
  if*        = 32;
  for*       = 33;
  while*     = 34;
  repeat*    = 35;
  in*        = 36; (** IN *)
  case*      = 37;
  of*        = 38;
  bar*       = 39; (** |  *)
  comma*     = 40;
  colon*     = 41;
  becomes*   = 42; (** := *)
  rparen*    = 44; (** )  *)
  then*      = 47;
  to*        = 48;
  do*        = 49;
  by*        = 50;
  semicol*   = 52;
  end*       = 53;
  else*      = 55;
  elsif*     = 56;
  until*     = 57;
  procedure* = 58;
  return*    = 59;
  const*     = 63;
  array*     = 64;
  var*       = 65;
  type*      = 66;
  begin*     = 67;
  import*    = 68;
  module*    = 69;
  eot        = 70; (** End of text *)

  (** - **)
  maxInt* = 7FFFFFFFH;
  minInt* = -maxInt - 1;
  maxTrans*    = 8;    (** Max translation entries in a comment *)
  maxLangLen*  = 5;    (** Max length of a language code *)
  maxTransLen* = 2048; (** Max length of a translation string *)

TYPE
  LONGINT = M.LONGINT;

VAR
  moduleFname: ARRAY 128 OF CHAR;
  r: Files.Rider;
  line, col: INTEGER;
  nextLine: BOOLEAN; (** Used in Read *)

  id*: ARRAY 64 OF CHAR;    (** When sym = ident *)
  len*: INTEGER;            (** When sym = ident or string *)
  ival*: LONGINT;           (** When sym = int *)
  sval*: ARRAY 256 OF CHAR; (** When sym = string *)

  ch: CHAR; (* Used in Get *)
  pendingSym: INTEGER; (* Saved symbol for real literal lookahead *)

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
  pendingSym := 0;
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

(** Converts a decimal number ip.fracNum/fracDen to IEEE 754
    single-precision bit pattern using pure integer arithmetic. *)
PROCEDURE EncodeReal(ip, fracNum, fracDen: INTEGER): INTEGER;
VAR exp, mantissa, num, den, bit, result: INTEGER;
BEGIN
  IF (ip = 0) & (fracNum = 0) THEN
    result := 0
  ELSE
    num := ip * fracDen + fracNum;
    den := fracDen;
    exp := 0;
    WHILE num - den >= den DO
      den := den + den;
      INC(exp)
    END;
    WHILE num < den DO
      num := num + num;
      DEC(exp)
    END;
    num := num - den;
    mantissa := 0;
    bit := 22;
    WHILE bit >= 0 DO
      num := num + num;
      IF num >= den THEN
        mantissa := mantissa + LSL(1, bit);
        num := num - den
      END;
      DEC(bit)
    END;
    result := LSL(exp + 127, 23) + mantissa
  END
RETURN result END EncodeReal;

PROCEDURE Get*(VAR sym: INTEGER);
VAR quote: CHAR;
  marked: BOOLEAN;
  n, hdigits: INTEGER;
  hval: LONGINT;
  fracNum, fracDen: INTEGER;
  hexOnly, hexOverflow: BOOLEAN;
  kw: ARRAY 32 OF CHAR;
BEGIN
  IF pendingSym # 0 THEN
    sym := pendingSym;
    pendingSym := 0
  ELSE
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
    ELSIF ch = '.' THEN Read;
      IF ch = '.' THEN sym := upto; Read ELSE sym := period END
    ELSIF ch = ',' THEN sym := comma; Read
    ELSIF ch = '*' THEN sym := times; Read
    ELSIF ch = '/' THEN sym := rdiv; Read
    ELSIF ch = '+' THEN sym := plus; Read
    ELSIF ch = '-' THEN sym := minus; Read
    ELSIF ch = '(' THEN Read;
      IF ch = '*' THEN Comment; sym := null ELSE sym := lparen END
    ELSIF ch = ')' THEN sym := rparen; Read
    ELSIF ch = '&' THEN sym := and; Read
    ELSIF ch = '~' THEN sym := not; Read
    ELSIF ch = '[' THEN sym := lbrak; Read
    ELSIF ch = ']' THEN sym := rbrak; Read
    ELSIF ch = '{' THEN sym := lbrace; Read
    ELSIF ch = '}' THEN sym := rbrace; Read
    ELSIF ch = '|' THEN sym := bar; Read
    ELSIF (ch = '"') OR (ch = "'") THEN (* " *)
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
      ival := 0; hval := 0; hdigits := 0; hexOnly := FALSE; hexOverflow := FALSE;
      REPEAT
        IF ('0' <= ch) & (ch <= '9') THEN
          n := ORD(ch) - ORD('0');
          IF ival <= (M.maxLongInt - n) DIV 10 THEN
            ival := ival * 10 + n
          ELSE Mark(E.intOverflow)
          END
        ELSE (* 'A'..'F' *)
          n := ORD(ch) - ORD('A') + 10;
          hexOnly := TRUE
        END;
        IF hdigits < 16 THEN
          hval := hval * 16 + n;
          INC(hdigits)
        ELSE hexOverflow := TRUE
        END;
        Read
      UNTIL ~(('0' <= ch) & (ch <= '9')) & ~(('A' <= ch) & (ch <= 'F'));
      IF ch = 'H' THEN
        IF hexOverflow THEN Mark(E.intOverflow) END;
        ival := hval; sym := int; Read
      ELSIF ch = 'X' THEN
        IF hexOverflow OR (hval > 0FFFFH) THEN Mark(E.intOverflow) END;
        len := 1;
        sval[0] := CHR(M.SHORT(hval));
        sval[1] := 0X;
        sym := string;
        Read
      ELSIF hexOnly THEN
        Mark(E.badHex); ival := hval; sym := int
      ELSIF ch = '.' THEN
        Read;
        IF ('0' <= ch) & (ch <= '9') THEN
          fracNum := 0; fracDen := 1;
          WHILE ('0' <= ch) & (ch <= '9') DO
            n := ORD(ch) - ORD('0');
            IF fracDen <= maxInt DIV 10 THEN
              fracNum := fracNum * 10 + n;
              fracDen := fracDen * 10
            END;
            Read
          END;
          ival := EncodeReal(M.SHORT(ival), fracNum, fracDen);
          sym := real
        ELSIF ch = '.' THEN
          sym := int;
          pendingSym := upto;
          Read
        ELSE
          sym := int;
          pendingSym := period
        END
      ELSE
        sym := int
      END
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
      ELSIF kw = 'IN'     THEN sym := in
      ELSIF kw = 'FOR'    THEN sym := for
      ELSIF kw = 'TO'     THEN sym := to
      ELSIF kw = 'BY'     THEN sym := by
      ELSIF kw = 'CASE'   THEN sym := case
      ELSIF kw = 'OF'     THEN sym := of
      ELSIF kw = 'ARRAY'  THEN sym := array
      ELSIF kw = 'CONST'  THEN sym := const      
      ELSIF kw = 'TYPE'   THEN sym := type      
      ELSIF kw = 'PROCEDURE' THEN sym := procedure
      ELSIF kw = 'RETURN' THEN sym := return
      ELSE Mark(E.unknownKW)
      END
    ELSE sym := null; Read
    END
  UNTIL sym # null
  END (* IF pendingSym *)
END Get;

END Scanner.
