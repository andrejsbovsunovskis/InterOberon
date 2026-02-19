MODULE Linker;
IMPORT Files, Strings, Out, Lang;

CONST
  version = 1;
  (** Object file mark *)
  objFileMark = ORD('R') + 256 * (ORD('S') + 256 * (ORD('C') + 256 * version));
  (** Executable file mark *)
  exeFileMark = ORD('E') + 256 * (ORD('X') + 256 * (ORD('E') + 256 * version));

VAR
  objFile: Files.File;
  exeFile: Files.File;
  objRider: Files.Rider;
  exeRider: Files.Rider;

(** Read object file and write to executable *)
PROCEDURE CopyCode(): BOOLEAN;
VAR mark, n: INTEGER;
  b: BYTE;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  Files.ReadInt(objRider, mark);
  IF mark = objFileMark THEN
    (* Write executable file mark *)
    Files.WriteInt(exeRider, exeFileMark);
    
    (* Copy rest of the file *)
    Files.Read(objRider, b);
    WHILE ~objRider.eof DO
      Files.Write(exeRider, b);
      Files.Read(objRider, b)
    END;
    ok := TRUE
  ELSE
    Lang.Write(Lang.invalidObjFile); Out.Ln
  END
RETURN ok END CopyCode;

(** Link single module *)
PROCEDURE Link*(modName: ARRAY OF CHAR): BOOLEAN;
VAR objName, exeName: ARRAY 256 OF CHAR;
  ok: BOOLEAN;
BEGIN
  ok := FALSE;
  
  (* Prepare file names *)
  Strings.Copy(modName, objName);
  Strings.Append('.o', objName);
  Strings.Copy(modName, exeName);
  
  (* Open object file *)
  objFile := Files.Old(objName);
  IF objFile # NIL THEN
    Files.Set(objRider, objFile, 0);
    
    (* Create executable file *)
    exeFile := Files.New(exeName);
    IF exeFile # NIL THEN
      Files.Set(exeRider, exeFile, 0);
      
      (* Copy code *)
      IF CopyCode() THEN
        Files.Register(exeFile);
        Lang.Write(Lang.linkComplete); Out.Char(' ');
        Out.String(exeName); Out.Ln;
        ok := TRUE
      END
    ELSE
      Lang.Write(Lang.cantCreateExe); Out.Char(' '); Out.Char('"');
      Out.String(exeName); Out.String('".'); Out.Ln
    END
  ELSE
    Lang.Write(Lang.cantOpenObj); Out.Char(' '); Out.Char('"');
    Out.String(objName); Out.String('".'); Out.Ln
  END
RETURN ok END Link;

END Linker.
