MODULE PtrLib;
(* Phase 2 cross-module pointer test: exports a self-recursive
   POINTER TO RECORD and helpers, exercising tcTypeRef in the .sym
   round-trip plus identity sharing across modules. *)

TYPE
  Node* = POINTER TO NodeDesc;
  NodeDesc* = RECORD
    v*: INTEGER;
    next*: Node
  END;

PROCEDURE New*(v: INTEGER): Node;
VAR n: Node;
BEGIN NEW(n); n.v := v; n.next := NIL
RETURN n END New;

PROCEDURE Cons*(v: INTEGER; tail: Node): Node;
VAR n: Node;
BEGIN NEW(n); n.v := v; n.next := tail
RETURN n END Cons;

PROCEDURE Sum*(list: Node): INTEGER;
VAR s: INTEGER;
BEGIN s := 0;
  WHILE list # NIL DO
    s := s + list.v;
    list := list.next
  END
RETURN s END Sum;

END PtrLib.
