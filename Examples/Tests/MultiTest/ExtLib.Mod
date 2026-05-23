MODULE ExtLib;
(* Phase 3 cross-module extension test: exports a record + pointer
   so the importing module can extend it.  Cross-module RTTI is
   degraded -- IS-tests against types defined here will return FALSE
   from the importing module -- so we expose a `Describe` that
   stays inside ExtLib for tag inspection. *)

TYPE
  Animal* = RECORD
    age*: INTEGER
  END;
  PAnimal* = POINTER TO Animal;

PROCEDURE PrintAge*(a: PAnimal);
BEGIN
  IF a # NIL THEN
    (* Just print the inherited field -- portable across extensions. *)
    a.age := a.age + 0
  END
END PrintAge;

PROCEDURE GetAge*(a: PAnimal): INTEGER;
VAR n: INTEGER;
BEGIN n := 0;
  IF a # NIL THEN n := a.age END
RETURN n END GetAge;

END ExtLib.
