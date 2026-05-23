MODULE SuitePtr;
(* Pointers: NEW/NIL/^, list, tree, VAR/value mix. *)

IMPORT Out;

TYPE
  Node = POINTER TO NodeDesc;
  NodeDesc = RECORD
    v: INTEGER;
    next: Node
  END;

  TreeNode = POINTER TO TreeDesc;
  TreeDesc = RECORD
    v: INTEGER;
    left, right: TreeNode
  END;

VAR
  head, p, p2: Node;
  i, sum, count: INTEGER;
  root: TreeNode;
  nilCheck: Node;
  gNilInit: Node;
  gpNilInit: PROCEDURE;

PROCEDURE Push(VAR list: Node; v: INTEGER);
VAR n: Node;
BEGIN
  NEW(n); n.v := v; n.next := list; list := n
END Push;

PROCEDURE Sum(list: Node): INTEGER;
VAR s: INTEGER;
BEGIN s := 0;
  WHILE list # NIL DO
    s := s + list.v;
    list := list.next
  END
RETURN s END Sum;

PROCEDURE Length(list: Node): INTEGER;
VAR n: INTEGER;
BEGIN n := 0;
  WHILE list # NIL DO INC(n); list := list.next END
RETURN n END Length;

PROCEDURE InsertBST(VAR t: TreeNode; v: INTEGER);
BEGIN
  IF t = NIL THEN
    NEW(t); t.v := v; t.left := NIL; t.right := NIL
  ELSIF v < t.v THEN
    InsertBST(t.left, v)
  ELSE
    InsertBST(t.right, v)
  END
END InsertBST;

PROCEDURE InorderPrint(t: TreeNode);
BEGIN
  IF t # NIL THEN
    InorderPrint(t.left);
    Out.Int(t.v, 0); Out.Char(' ');
    InorderPrint(t.right)
  END
END InorderPrint;

PROCEDURE NilLocalPart;
VAR locP: Node; locQ: PROCEDURE;
BEGIN
  IF locP = NIL THEN Out.String('local ptr nil') ELSE Out.String('local ptr set') END; Out.Ln;
  IF locQ = NIL THEN Out.String('local proc nil') ELSE Out.String('local proc set') END; Out.Ln
END NilLocalPart;

BEGIN
  Out.String('=== linked list ==='); Out.Ln;
  head := NIL;
  FOR i := 1 TO 5 DO Push(head, i) END;
  sum := Sum(head);
  count := Length(head);
  Out.String('len='); Out.Int(count, 0); Out.Ln;
  Out.String('sum='); Out.Int(sum, 0); Out.Ln;
  Out.String('values:');
  p := head;
  WHILE p # NIL DO
    Out.Char(' '); Out.Int(p.v, 0);
    p := p.next
  END;
  Out.Ln;

  Out.String('=== explicit vs auto deref ==='); Out.Ln;
  Out.String('head^.v = '); Out.Int(head^.v, 0); Out.Ln;
  Out.String('head.v  = '); Out.Int(head.v,  0); Out.Ln;

  Out.String('=== second-level deref ==='); Out.Ln;
  p := head;
  p2 := p.next;
  Out.String('p2^.v = '); Out.Int(p2^.v, 0); Out.Ln;
  Out.String('head^.next^.v = '); Out.Int(head^.next^.v, 0); Out.Ln;

  Out.String('=== nil checks ==='); Out.Ln;
  nilCheck := NIL;
  IF nilCheck = NIL THEN Out.String('nilCheck = NIL: yes') END; Out.Ln;
  IF head # NIL THEN Out.String('head # NIL: yes') END; Out.Ln;

  Out.String('=== tree (BST inorder) ==='); Out.Ln;
  root := NIL;
  InsertBST(root, 5);
  InsertBST(root, 3);
  InsertBST(root, 7);
  InsertBST(root, 1);
  InsertBST(root, 4);
  InsertBST(root, 6);
  InsertBST(root, 9);
  InorderPrint(root); Out.Ln;

  Out.String('=== nil init ==='); Out.Ln;
  IF gNilInit = NIL THEN Out.String('global ptr nil') ELSE Out.String('global ptr set') END; Out.Ln;
  IF gpNilInit = NIL THEN Out.String('global proc nil') ELSE Out.String('global proc set') END; Out.Ln;
  NilLocalPart
END SuitePtr.
