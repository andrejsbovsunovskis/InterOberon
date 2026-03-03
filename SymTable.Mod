MODULE SymTable;
IMPORT Out, S := Scanner, E := ErrorMsg, Strings, Kernel, L := Lang, M := Machine, Files;

CONST
  (** Object Classes **)
  Head*  = 0;
  Const* = 1; (** Non-standard procedures also go here *)
  Var*   = 2; (** Variables and value parameters *)
  Par*   = 3; (** Var-parameters *)
  Typ*   = 5;
  Mod*   = 8;

  (** Type Forms **)
  Bool*  = 2;
  Char*  = 3;
  Int*   = 4;
  SFunc* = 7;
  NoTyp* = 9;
  Proc*  = 10;

TYPE
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

  ObjectDesc* = RECORD
    names*: Name;
    exported*: BOOLEAN;
    class*: INTEGER; (** See Object Classes *)
    dsc*: Object;
    next*: Object;
    type*: Type;
    val*: INTEGER (** Address for variables, number for procedures *)
  END;

  TypeDesc* = RECORD
    form*: INTEGER;
    nofpars*: INTEGER;
    dsc*: Object;
    base*: Type;
    size*: INTEGER (** In bytes *)
  END;

VAR
  topScope: Object;
  dummy*: Object;

  (** Standard Types **)
  boolType*, charType*, intType*, noType*: Type;

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
  L.FindUniObj('ORD', s); SetName(U.names, s);
  U.class := SFunc;
  U.val := 31;
  U.type := intType;

  NEW(U.next);
  U := U.next;
  L.FindUniObj('CHR', s); SetName(U.names, s);
  U.class := SFunc;
  U.val := 32;
  U.type := charType;

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

(** Returns TRUE if types t1 and t2 are assignment-compatible (t1 := t2) *)
PROCEDURE TypesCompatible*(t1, t2: Type): BOOLEAN;
RETURN t1.form = t2.form END TypesCompatible;

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
    p.names := NIL;
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
  M.class := Const; M.val := 1;
  L.FindModObj(num, 'Char', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 1; M.type.base := noType;
  (* Parameter of In.Char *)
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Par; SetName(p.names, 'c'); p.type := charType;

  (* In.Int *)
  NEW(M.next); M := M.next;
  M.class := Const; M.val := 2;
  L.FindModObj(num, 'Int', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 1; M.type.base := noType;
  (* Parameter of In.Int *)
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Par; SetName(p.names, 'i'); p.type := intType
END ImportIn;

(** num is Lang-internal number of module M *)
PROCEDURE ImportOut*(M: Object; num: INTEGER);
VAR p: Object;
  s: ARRAY 64 OF CHAR;
BEGIN
  (* Out.Char *)
  NEW(M.dsc); M := M.dsc;
  M.class := Const; M.val := 5;
  L.FindModObj(num, 'Char', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 1; M.type.base := noType;
  (* Parameter of Out.Char *)
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Var; SetName(p.names, 'c'); p.type := charType;

  (* Out.Int *)
  NEW(M.next); M := M.next;
  M.class := Const; M.val := 6;
  L.FindModObj(num, 'Int', s); SetName(M.names, s);
  NEW(M.type); M.type.form := Proc;
  M.type.nofpars := 2; M.type.base := noType;
  (* Parameters of Out.Int *)
  NEW(M.type.dsc); p := M.type.dsc;
  p.class := Var; SetName(p.names, 'i'); p.type := intType;
  NEW(p.next); p := p.next;
  p.class := Var; SetName(p.names, 'n'); p.type := intType;

  (* Out.Ln *)
  NEW(M.next); M := M.next;
  M.class := Const; M.val := 7;
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
        Out.String(' at address '); Out.Int(p.val, 0)
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

(** Export module symbols to .sym file *)
PROCEDURE ExportModule*(modNames: Name);
CONST
  version = 1;
  symFileMark = ORD('S') + 256 * (ORD('Y') + 256 * (ORD('M') + 256 * version));
  endMark = -1;
VAR
  F: Files.File;
  R: Files.Rider;
  fname: ARRAY 256 OF CHAR;
  s: ARRAY 64 OF CHAR;
  p: Object;
BEGIN
  (* Create .sym file *)
  Strings.Copy(modNames.str, fname);
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
        Files.WriteNum(R, p.val);

        IF p.type # NIL THEN
          Files.WriteNum(R, p.type.form);
          Files.WriteNum(R, p.type.size)
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

  NEW(dummy);
  OpenScope;
  InitUniverse;
  OpenScope
END Init;

PROCEDURE CreateType(form, size: INTEGER): Type;
VAR T: Type;
BEGIN NEW(T); T.form := form; T.size := size
RETURN T END CreateType;

BEGIN
  boolType := CreateType(Bool , 1);
  charType := CreateType(Char , 2);
  intType  := CreateType(Int  , 4);
  noType   := CreateType(NoTyp, 0)
END SymTable.
