MODULE Linker;
IMPORT Files, Strings, E := ErrorMsg, M := Machine;

CONST
  version = 1;
  (** Object file mark *)
  objFileMark = ORD('A') + 256 * (ORD('R') + 256 * (ORD('M') + 256 * version));
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
    M.WriteError(E.invalidObjFile)
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
  Strings.Append('.obj', objName);
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
        M.WriteS(E.linkComplete, exeName);
        ok := TRUE
      END
    ELSE
      M.WriteErrorS(E.cantCreateExe, exeName)
    END
  ELSE
    M.WriteErrorS(E.cantOpenObj, objName)
  END
RETURN ok END Link;

END Linker.
