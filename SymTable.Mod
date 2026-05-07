MODULE SymTable;
IMPORT Out, S := Scanner, E := ErrorMsg, Strings, Kernel, L := Lang, M := Machine, Files, Utf8;

CONST
  (** Object Classes **)
  Head*   = 0;
  Const*  = 1; (** User defined procedures also are constants *)
  Var*    = 2; (** Variables and value parameters *)
  VarPar* = 3; (** VAR-parameters *)
  Typ*    = 5;
  SProc*  = 6; (** Standard procedure *)
  SFunc*  = 7; (** Standard functional procedure *)
  Mod*    = 8;

  (** Type Forms **)
  Bool*     = 2;
  Char*     = 3;
  Int*      = 4;
  Set*      = 5;
  Byte*     = 6;
  Real*     = 7;
  NoTyp*    = 9;
  Proc*     = 10;
  ShortInt* = 11;
  LongInt*  = 12;
  LongSet*  = 13;
  Array*    = 14;
  Record*   = 15;
  String*   = 16; (** String literals and CONST only; not a user-declarable type *)

TYPE
  LONGINT = M.LONGINT;
  LONGREAL = M.LONGREAL;

  Object* = POINTER TO ObjectDesc;
  Type* = POINTER TO TypeDesc;
  Name* = POINTER TO NameDesc;
  Lang* = POINTER TO LangDesc;

  NameDesc* = RECORD
    str*: ARRAY 64 OF CHAR;
    lang*: ARRAY 6 OF CHAR;
    next: Name
  END;

  LangDesc* = RECORD
    code*: ARRAY 6 OF CHAR;
    next: Lang
  END;

  StringEntry* = POINTER TO StringEntryDesc;
  StringEntryDesc* = RECORD
    bytes*: ARRAY 256 OF CHAR;
    nChars*: INTEGER; (** CHAR count including final 0X *)
    next*: StringEntry
  END;

  ObjectDesc* = RECORD
    names*: Name;
    exported*: BOOLEAN;
    class*: INTEGER; (** See Object Classes *)
    dsc*: Object;
    next*: Object;
    type*: Type;
    lev*: INTEGER; (** Scope level: 0 - global, > 0 - local *)
    address*: LONGINT; (** Address for variables, number for standard procedures *)
    (** class = Const: integers, pool index (String), SET/LONGSET bits, proc offset — all in intVal. *)
    intVal*: LONGINT;
    realVal*: LONGREAL;
    readOnly*: BOOLEAN; (** non-VAR array params and imported variables *)
    procResolved*: BOOLEAN; (** TRUE once final entry address is recorded *)
    fixupList*: INTEGER (** Only for procedures. Word position of last unpatched BL, 0 = empty *)
  END;

  TypeDesc* = RECORD
    form*: INTEGER;
    len*: INTEGER; (** Array length; nofpars for Proc *)
    openRank*: INTEGER; (** Number of open array dimensions *)
    nofpars*: INTEGER;
    dsc*: Object;
    base*: Type;
    size*: INTEGER (** In bytes *)
  END;

VAR
  topScope*: Object;
  dummy*: Object;
  curLev*: INTEGER; (** Current scope level: 0 = module, > 0 = procedure *)

  (** Standard Types **)
  boolType*, charType*, intType*, setType*, byteType*, realType*, noType*: Type;
  shortIntType*, longIntType*, longSetType*: Type;

  (** Runtime string pool for literals (dedup by content); index for relocations *)
  strPool*: StringEntry;
  nofPoolStrings*: INTEGER;

  (** - **)
  langs: Lang;

PROCEDURE SetNameLang*(VAR names: Name; langCode, str: ARRAY OF CHAR);
VAR n, p: Name;
BEGIN
  NEW(n);
  Strings.Copy(langCode, n.lang);
  Strings.Copy(str, n.str);

  (* Add n to the end of the names list *)
  p := names;
  IF p # NIL THEN
    WHILE p.next # NIL DO p := p.next END;
    p.next := n
  ELSE
    names := n
  END
END SetNameLang;

PROCEDURE SetName*(VAR names: Name; str: ARRAY OF CHAR);
BEGIN
  SetNameLang(names, L.curLang, str)
END SetName;

PROCEDURE GetNameLang*(names: Name; langCode: ARRAY OF CHAR; VAR str: ARRAY OF CHAR);
VAR p: Name;
BEGIN
  IF names = NIL THEN
    str := ''
  ELSE
    p := names;
    WHILE (p # NIL) & (p.lang # langCode) DO p := p.next END;
    IF p # NIL THEN
      Strings.Copy(p.str, str)
    ELSE
      str := '' (*!TODO: Handle missing name *)
    END
  END
END GetNameLang;

PROCEDURE GetName*(names: Name; VAR str: ARRAY OF CHAR);
BEGIN
  IF names = NIL THEN
    str := ''
  ELSE
    Strings.Copy(names.str, str)
  END
END GetName;

PROCEDURE InitUniverse;
VAR U: Object;
  s: ARRAY 64 OF CHAR;
BEGIN
  U := topScope;
  NEW(U.next);
  U := U.next;
  L.FindUniObj('BOOLEAN', s); SetName(U.names, s);
  U.class := Typ;
  U.type := boolType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('CHAR', s); SetName(U.names, s);
  U.class := Typ;
  U.type := charType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('INTEGER', s); SetName(U.names, s);
  U.class := Typ;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('SET', s); SetName(U.names, s);
  U.class := Typ;
  U.type := setType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('ORD', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 31;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('CHR', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 32;
  U.type := charType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('ABS', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 33;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('ODD', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 34;
  U.type := boolType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('ASR', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 35;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('LSL', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 36;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('ROR', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 37;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('INC', s); SetName(U.names, s);
  U.class := SProc;
  U.address := 41;
  U.type := noType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('DEC', s); SetName(U.names, s);
  U.class := SProc;
  U.address := 42;
  U.type := noType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('INCL', s); SetName(U.names, s);
  U.class := SProc;
  U.address := 43;
  U.type := noType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('EXCL', s); SetName(U.names, s);
  U.class := SProc;
  U.address := 44;
  U.type := noType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('BYTE', s); SetName(U.names, s);
  U.class := Typ;
  U.type := byteType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('REAL', s); SetName(U.names, s);
  U.class := Typ;
  U.type := realType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('FLOOR', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 38;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('FLT', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 39;
  U.type := realType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('SHORTINT', s); SetName(U.names, s);
  U.class := Typ;
  U.type := shortIntType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('LONGINT', s); SetName(U.names, s);
  U.class := Typ;
  U.type := longIntType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('LONGSET', s); SetName(U.names, s);
  U.class := Typ;
  U.type := longSetType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('LEN', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 40;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('SHORT', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 45;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('LONG', s); SetName(U.names, s);
  U.class := SFunc;
  U.address := 46;
  U.type := intType;

  U.next := dummy
END InitUniverse;

PROCEDURE OpenScope*;
VAR p: Object;
BEGIN
  p := topScope;
  NEW(topScope);
  topScope.dsc := p;
  topScope.class := Head;

  (* Remove dummy from previous top scope *)
  IF p # NIL THEN
    WHILE p.next # dummy DO p := p.next END;
    p.next := NIL
  END;

  topScope.next := dummy
END OpenScope;

PROCEDURE CloseScope*;
VAR p: Object;
BEGIN
  topScope := topScope.dsc;
  p := topScope;
  WHILE p.next # NIL DO p := p.next END;
  p.next := dummy
END CloseScope;

PROCEDURE IncLev*;
BEGIN INC(curLev)
END IncLev;

PROCEDURE DecLev*;
BEGIN DEC(curLev)
END DecLev;

(** Returns TRUE if t1 and t2 can appear together in a comparison (symmetric, no narrowing check). *)
PROCEDURE TypesCompatible*(t1, t2: Type): BOOLEAN;
RETURN (t1.form = t2.form)
    OR (t1.form IN {Int, Byte, ShortInt, LongInt}) & (t2.form IN {Int, Byte, ShortInt, LongInt})
    OR (t1.form IN {Set, LongSet}) & (t2.form IN {Set, LongSet})
END TypesCompatible;

(** Returns TRUE if src is assignable to dst without explicit narrowing.
    Rules:
      BYTE <-> all integer types  (bidirectional special case).
      ShortInt <= Int <= LongInt  (only widening is implicit; narrowing needs SHORT).
      Set <= LongSet              (only widening is implicit; narrowing needs SHORT). *)
PROCEDURE TypeAssignable*(dst, src: Type): BOOLEAN;
VAR df, sf: INTEGER;
BEGIN
  df := dst.form; sf := src.form;
  RETURN (df = sf)
    OR (df = Byte) & (sf IN {Byte, ShortInt, Int, LongInt})    (* any int -> BYTE *)
    OR (sf = Byte) & (df IN {Byte, ShortInt, Int, LongInt})    (* BYTE -> any int *)
    OR (df = Int)     & (sf = ShortInt)                         (* SHORTINT -> INTEGER *)
    OR (df = LongInt) & (sf IN {ShortInt, Int})                 (* ShortInt/Int -> LONGINT *)
    OR (df = LongSet) & (sf = Set)                              (* SET -> LONGSET *)
END TypeAssignable;

PROCEDURE ThisObject*(): Object;
VAR scope, p: Object;
  s: ARRAY 64 OF CHAR;
BEGIN
  scope := topScope;
  REPEAT
    p := scope.next;
    GetName(p.names, s);
    WHILE (p.next # NIL) & (s # S.id) DO
      p := p.next;
      GetName(p.names, s)
    END;
    scope := scope.dsc
  UNTIL (scope = NIL) OR (s = S.id);
  IF s # S.id THEN p := NIL END
RETURN p END ThisObject;

PROCEDURE ThisImport*(M: Object): Object;
VAR p: Object;
  s: ARRAY 64 OF CHAR;
BEGIN
  p := M.dsc;
  IF p # NIL THEN GetName(p.names, s) END;
  WHILE (p # NIL) & (s # S.id) DO
    p := p.next;
    IF p # NIL THEN GetName(p.names, s) END
  END
RETURN p END ThisImport;

PROCEDURE NewObject*(class: INTEGER; name: ARRAY OF CHAR): Object;
VAR p: Object;
  s: ARRAY 64 OF CHAR;
BEGIN
  SetName(dummy.names, name);

  p := topScope;
  GetName(p.next.names, s);
  WHILE s # name DO p := p.next; GetName(p.next.names, s) END;

  IF p.next = dummy THEN
    NEW(p.next);
    p := p.next;
    p.next := dummy;
    p.class := class;
    p.exported := FALSE;
    p.lev := curLev;
    p.names := NIL;
    p.procResolved := FALSE;
    p.fixupList := 0;
    SetName(p.names, name);
    dummy.names := NIL
  ELSE S.Mark(E.multipleDecl); p := p.next
  END
RETURN p END NewObject;

(** num is Lang-internal number of module M *)
PROCEDURE ImportIn*(M: Object; num: INTEGER);
VAR p: Object;
  s: ARRAY 64 OF CHAR;
BEGIN
  (* In.Char *)
  NEW(M.dsc); M := M.dsc;
  M.class := Const; M.address := -1; M.intVal := M.address; M.procResolved := TRUE;
  L.FindModObj(num, 'Char', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 1; M.type.base := noType;
  (* Parameter of In.Char *)
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := VarPar; SetName(p.names, 'c'); p.type := charType;

  (* In.Int *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -2; M.intVal := M.address; M.procResolved := TRUE;
  L.FindModObj(num, 'Int', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 1; M.type.base := noType;
  (* Parameter of In.Int *)
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := VarPar; SetName(p.names, 'i'); p.type := intType;

  (* In.Line — open ARRAY OF CHAR by VAR reference, hidden length *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -3; M.intVal := M.address; M.procResolved := TRUE;
  L.FindModObj(num, 'Line', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 1; M.type.base := noType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := VarPar; SetName(p.names, 'name');
  NEW(p.type); p.type.form := Array; p.type.base := charType;
  p.type.len := 0; p.type.size := 8; p.type.openRank := 1
END ImportIn;

(** num is Lang-internal number of module M *)
PROCEDURE ImportOut*(M: Object; num: INTEGER);
VAR p: Object;
  s: ARRAY 64 OF CHAR;
BEGIN
  (* Out.Char *)
  NEW(M.dsc); M := M.dsc;
  M.class := Const; M.address := -5; M.intVal := M.address; M.procResolved := TRUE;
  L.FindModObj(num, 'Char', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 1; M.type.base := noType;
  (* Parameter of Out.Char *)
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Var; SetName(p.names, 'c'); p.type := charType;

  (* Out.String — open ARRAY OF CHAR by reference (VarPar read-only), hidden length *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -10; M.intVal := M.address; M.procResolved := TRUE;
  L.FindModObj(num, 'String', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 1; M.type.base := noType;
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := VarPar; p.readOnly := TRUE; SetName(p.names, 's');
  NEW(p.type); p.type.form := Array; p.type.base := charType;
  p.type.len := 0; p.type.size := 8; p.type.openRank := 1;

  (* Out.Int *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -6; M.intVal := M.address; M.procResolved := TRUE;
  L.FindModObj(num, 'Int', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 2; M.type.base := noType;
  (* Parameters of Out.Int *)
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Var; SetName(p.names, 'i'); p.type := longIntType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'n'); p.type := intType;

  (* Out.Ln *)
  NEW(M.next); M := M.next;
  M.class := Const; M.address := -7; M.intVal := M.address; M.procResolved := TRUE;
  L.FindModObj(num, 'Ln', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 0; M.type.base := noType
END ImportOut;

(** Loads symbol data of module to M by M.name *)
PROCEDURE Import*(M: Object);
VAR s: ARRAY 32 OF CHAR;
  mname: ARRAY 64 OF CHAR;
  num: INTEGER;
BEGIN
  GetName(M.names, mname); (*!FIXME ?*)
  L.FindModule(mname, s, num);
  IF s = 'In' THEN ImportIn(M, num)
  ELSIF s = 'Out' THEN ImportOut(M, num)
  ELSE S.Mark(E.noModule)
  END
END Import;

PROCEDURE PrintIndent(n: INTEGER);
BEGIN WHILE n > 0 DO Out.String('  '); DEC(n) END
END PrintIndent;

PROCEDURE Debug*(scope: Object; indent: INTEGER);
VAR p: Object;
  s: ARRAY 64 OF CHAR;
BEGIN
  WHILE scope # NIL DO
    p := scope;
    WHILE p # NIL DO
      PrintIndent(indent);
      IF p = dummy THEN Out.String('Dummy')
      ELSIF p.class = Head THEN Out.String('Header')
      ELSIF p.class = Var THEN
        GetName(p.names, s);
        Out.String('Variable "'); Out.String(s);
        Out.String('" of type with form '); Out.Int(p.type.form, 0);
        Out.String(' at address '); Out.Int(M.SHORT(p.address), 0)
      ELSIF p.class = Typ THEN
        GetName(p.names, s);
        Out.String('Type "'); Out.String(s);
        Out.String('", refers to type with form ');
        Out.Int(p.type.form, 0)
      ELSIF p.class = Const THEN
        GetName(p.names, s);
        Out.String('Constant "'); Out.String(s);
        Out.String('"');
        IF p.type.form = Proc THEN Out.String(' of procedure type with ');
          Out.Int(p.type.nofpars, 0); Out.String(' parameters'); Out.Ln;
          Debug(p.type.dsc, indent + 1)
        ELSE Out.String(' of type with form'); Out.Int(p.type.form, 0)
        END
      ELSIF p.class = Mod THEN
        GetName(p.names, s);
        Out.String('Module "'); Out.String(s);
        Out.String('":'); Out.Ln; Debug(p.dsc, indent + 1)
      ELSE Out.String('Unknown object')
      END;
      Out.Ln;
      p := p.next
    END;
    scope := scope.dsc;
    IF scope # NIL THEN
      PrintIndent(indent);
      Out.String('--- Next scope ---'); Out.Ln
    END
  END
END Debug;

PROCEDURE ShowDebug*;
BEGIN Debug(topScope, 0)
END ShowDebug;

PROCEDURE WriteString(VAR R: Files.Rider; s: ARRAY OF CHAR);
BEGIN
  Files.WriteString(R, s); Files.Write(R, 0)
END WriteString;

PROCEDURE OutputLangs(VAR R: Files.Rider);
VAR l: Lang;
BEGIN
  l := langs;
  WHILE l # NIL DO
    WriteString(R, l.code);
    l := l.next
  END;
  Files.Write(R, 0) (* End of languages marker *)
END OutputLangs;

PROCEDURE OutputNames(VAR R: Files.Rider; names: Name);
VAR l: Lang;
  s: ARRAY 64 OF CHAR;
BEGIN
  l := langs;
  WHILE l # NIL DO
    GetNameLang(names, l.code, s);
    IF s = '' THEN
      WriteString(R, names.str) (* Fallback to name in first language *)
    ELSE
      WriteString(R, s)
    END;
    l := l.next
  END;
  Files.Write(R, 0) (* End of names marker *)
END OutputNames;

PROCEDURE AddLang*(code: ARRAY OF CHAR);
VAR l, n, tail: Lang;
BEGIN
  tail := NIL;
  l := langs;
  WHILE (l # NIL) & (l.code # code) DO tail := l; l := l.next END;

  IF l = NIL THEN
    NEW(n);
    Strings.Copy(code, n.code);
    IF tail = NIL THEN langs := n ELSE tail.next := n END
  END
END AddLang;

PROCEDURE ResetStringPool*;
BEGIN strPool := NIL; nofPoolStrings := 0
END ResetStringPool;

PROCEDURE PoolEntry*(idx: INTEGER): StringEntry;
VAR e: StringEntry;
  i: INTEGER;
BEGIN
  e := strPool;
  i := 0;
  WHILE (e # NIL) & (i # idx) DO e := e.next; INC(i) END
RETURN e END PoolEntry;

PROCEDURE PoolBytesEqual(s: ARRAY OF CHAR; charLen: INTEGER; e: StringEntry): BOOLEAN;
VAR i: INTEGER;
  ok: BOOLEAN;
BEGIN
  ok := TRUE;
  IF (e = NIL) OR (e.nChars # charLen + 1) THEN ok := FALSE END;
  IF ok THEN
    i := 0;
    WHILE (i < charLen) & ok DO
      IF s[i] # e.bytes[i] THEN ok := FALSE END;
      INC(i)
    END
  END;
  IF ok & (e # NIL) & (e.bytes[charLen] # 0X) THEN ok := FALSE END;
RETURN ok END PoolBytesEqual;

PROCEDURE RegisterString*(s: ARRAY OF CHAR; charLen: INTEGER): INTEGER;
VAR e, tail: StringEntry;
  i, idx, res, hit, nscan: INTEGER;
BEGIN
  idx := 0;
  hit := -1;
  nscan := nofPoolStrings;
  WHILE idx < nscan DO
    e := PoolEntry(idx);
    IF PoolBytesEqual(s, charLen, e) THEN
      IF hit < 0 THEN hit := idx END
    END;
    INC(idx)
  END;
  IF hit >= 0 THEN
    res := hit
  ELSE
    NEW(e);
    i := 0;
    WHILE i < charLen DO e.bytes[i] := s[i]; INC(i) END;
    e.bytes[charLen] := 0X;
    e.nChars := charLen + 1;
    e.next := NIL;
    res := nofPoolStrings;
    IF strPool = NIL THEN strPool := e
    ELSE
      tail := strPool;
      WHILE tail.next # NIL DO tail := tail.next END;
      tail.next := e
    END;
    INC(nofPoolStrings)
  END
RETURN res END RegisterString;

PROCEDURE MakeStringType*(charLen: INTEGER): Type;
VAR T: Type;
BEGIN
  NEW(T);
  T.form := String;
  T.len := charLen + 1;
  T.size := (charLen + 1) * 2;
  T.openRank := 0;
  T.base := NIL
RETURN T END MakeStringType;

PROCEDURE IsCharArrayType*(t: Type): BOOLEAN;
BEGIN
RETURN (t # NIL) & (t.form = Array) & (t.base = charType)
END IsCharArrayType;

(** Append STRP section to rider R: pool count, then each literal as UTF-8 bytes + 0X (no per-string length prefix). *)
PROCEDURE WriteStrpSection*(VAR R: Files.Rider);
VAR e: StringEntry;
  i, utf8len: INTEGER;
  u8: ARRAY 1024 OF Utf8.SHORTCHAR;
BEGIN
  Files.WriteInt(R, nofPoolStrings);
  e := strPool;
  WHILE e # NIL DO
    Utf8.EncodeEx(e.bytes, e.nChars - 1, u8, utf8len);
    IF Utf8.Done THEN
      i := 0;
      WHILE i <= utf8len DO Files.Write(R, ORD(u8[i])); INC(i) END
    ELSE
      Files.Write(R, 0)
    END;
    e := e.next
  END
END WriteStrpSection;

(** Export module symbols to .sym file *)
PROCEDURE ExportModule*(modNames: Name);
CONST
  version = 3;
  symFileMark = ORD('S') + 256 * (ORD('Y') + 256 * (ORD('M') + 256 * version));
  endMark = -1;
VAR
  F: Files.File;
  R: Files.Rider;
  fname: ARRAY 256 OF CHAR;
  s: ARRAY 64 OF CHAR;
  p: Object;
  pe: StringEntry;
  i, utf8len: INTEGER;
  u8: ARRAY 1024 OF Utf8.SHORTCHAR;
BEGIN
  (* Create .sym file *)
  Strings.Copy(M.outDir, fname); Strings.Append(modNames.str, fname);
  Strings.Append('.sym', fname);
  F := Files.New(fname);

  IF F # NIL THEN
    Files.Set(R, F, 0);

    (* Write file mark and module name *)
    Files.WriteInt(R, symFileMark);
    Files.WriteInt(R, 0); (* Module key placeholder *)
    OutputLangs(R);
    OutputNames(R, modNames);

    (* Export each object *)
    p := topScope.next;
    WHILE p # dummy DO
      IF p.exported THEN
        Files.Write(R, p.class);
        OutputNames(R, p.names);
        Files.WriteNum(R, M.SHORT(p.address));

        IF p.type # NIL THEN
          Files.WriteNum(R, p.type.form);
          Files.WriteNum(R, p.type.size);
          IF (p.class = Const) & (p.type.form = String) THEN
            pe := PoolEntry(M.SHORT(p.intVal));
            IF pe # NIL THEN
              Utf8.EncodeEx(pe.bytes, pe.nChars - 1, u8, utf8len);
              IF Utf8.Done THEN
                i := 0;
                WHILE i <= utf8len DO Files.Write(R, ORD(u8[i])); INC(i) END
              ELSE
                Files.Write(R, 0)
              END
            ELSE
              Files.Write(R, 0)
            END
          END
        ELSE
          Files.WriteNum(R, NoTyp);
          Files.WriteNum(R, 0);
          Files.WriteNum(R, 0)
        END
      END;

      p := p.next
    END;
    Files.Write(R, 0); (* End marker *)
    Files.Register(F)
  ELSE
    M.WriteErrorS(E.cantCreateSym, fname)
  END
END ExportModule;

PROCEDURE Init*(curLang: ARRAY OF CHAR);
BEGIN
  AddLang(curLang);
  ResetStringPool;

  curLev := 0;
  NEW(dummy);
  OpenScope;
  InitUniverse;
  OpenScope
END Init;

PROCEDURE CreateType(form, size: INTEGER): Type;
VAR T: Type;
BEGIN NEW(T); T.form := form; T.size := size; T.openRank := 0
RETURN T END CreateType;

BEGIN
  strPool := NIL;
  nofPoolStrings := 0;
  boolType     := CreateType(Bool    , 1);
  charType     := CreateType(Char    , 2);
  intType      := CreateType(Int     , 4);
  setType      := CreateType(Set     , 4);
  byteType     := CreateType(Byte    , 1);
  realType     := CreateType(Real    , 4);
  noType       := CreateType(NoTyp   , 0);
  shortIntType := CreateType(ShortInt, 2);
  longIntType  := CreateType(LongInt , 8);
  longSetType  := CreateType(LongSet , 8)
END SymTable.
