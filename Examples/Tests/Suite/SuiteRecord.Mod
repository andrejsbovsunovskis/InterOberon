MODULE SuiteRecord;
IMPORT Out;

TYPE
  Point = RECORD x, y: INTEGER END;
  Pixel = RECORD
    pos: Point;
    color: BYTE
  END;
  RecWithArray = RECORD
    name: ARRAY 8 OF CHAR;
    sum: INTEGER
  END;

PROCEDURE BasicPart;
VAR p: Point;
BEGIN
  p.x := 11;
  p.y := 22;
  Out.Int(p.x, 0); Out.Char(' '); Out.Int(p.y, 0); Out.Ln;
  p.x := p.x + p.y;
  Out.Int(p.x, 0); Out.Ln
END BasicPart;

PROCEDURE NestedPart;
VAR px: Pixel;
BEGIN
  px.pos.x := 100;
  px.pos.y := 200;
  px.color := 7;
  Out.Int(px.pos.x, 0); Out.Char(' ');
  Out.Int(px.pos.y, 0); Out.Char(' ');
  Out.Int(px.color, 0); Out.Ln;
  px.pos.x := px.pos.x + px.pos.y + px.color;
  Out.Int(px.pos.x, 0); Out.Ln
END NestedPart;

PROCEDURE WithArrayPart;
VAR r: RecWithArray;
  i: INTEGER;
BEGIN
  r.name[0] := 'A'; r.name[1] := 'B'; r.name[2] := 'C'; r.name[3] := 0X;
  r.sum := 0;
  FOR i := 0 TO 2 DO r.sum := r.sum + (i + 1) END;
  FOR i := 0 TO 2 DO Out.Char(r.name[i]) END;
  Out.Char(' '); Out.Int(r.sum, 0); Out.Ln
END WithArrayPart;

PROCEDURE InArrayPart;
VAR pts: ARRAY 4 OF Point;
  i, total: INTEGER;
BEGIN
  FOR i := 0 TO 3 DO
    pts[i].x := i;
    pts[i].y := i * i
  END;
  total := 0;
  FOR i := 0 TO 3 DO total := total + pts[i].x + pts[i].y END;
  Out.Int(total, 0); Out.Ln;
  pts[2].x := 100;
  Out.Int(pts[2].x, 0); Out.Char(' ');
  Out.Int(pts[2].y, 0); Out.Ln
END InArrayPart;

PROCEDURE ShowVal(p: Point);
BEGIN
  Out.Int(p.x, 0); Out.Char(' '); Out.Int(p.y, 0); Out.Ln
END ShowVal;

PROCEDURE Bump(VAR p: Point; dx, dy: INTEGER);
BEGIN
  p.x := p.x + dx;
  p.y := p.y + dy
END Bump;

PROCEDURE ParamPart;
VAR p: Point;
BEGIN
  p.x := 5; p.y := 9;
  ShowVal(p);
  Out.Int(p.x, 0); Out.Char(' '); Out.Int(p.y, 0); Out.Ln;
  Bump(p, 10, 20);
  Out.Int(p.x, 0); Out.Char(' '); Out.Int(p.y, 0); Out.Ln
END ParamPart;

PROCEDURE AssignPart;
VAR a, b: Point;
  pa, pb: Pixel;
BEGIN
  a.x := 7; a.y := 8;
  b := a;
  Out.Int(b.x, 0); Out.Char(' '); Out.Int(b.y, 0); Out.Ln;
  a.x := 99;
  Out.Int(b.x, 0); Out.Char(' '); Out.Int(b.y, 0); Out.Ln;
  pa.pos.x := 1; pa.pos.y := 2; pa.color := 3;
  pb := pa;
  Out.Int(pb.pos.x, 0); Out.Char(' ');
  Out.Int(pb.pos.y, 0); Out.Char(' ');
  Out.Int(pb.color, 0); Out.Ln
END AssignPart;

BEGIN
  BasicPart;
  NestedPart;
  WithArrayPart;
  InArrayPart;
  ParamPart;
  AssignPart
END SuiteRecord.
