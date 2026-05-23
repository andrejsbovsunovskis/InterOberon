MODULE SuiteCase;
IMPORT Out;

PROCEDURE CaseBasic;
VAR x, res: INTEGER; ch: CHAR;
BEGIN
  x := 2;
  CASE x OF
    1: res := 10 |
    2: res := 20 |
    3: res := 30
  END;
  Out.Int(res, 0); Out.Ln;
  x := 5;
  res := 99;
  CASE x OF
    1: res := 10 |
    2: res := 20 |
    5: res := 99
  END;
  Out.Int(res, 0); Out.Ln;
  x := 4;
  CASE x OF
    1, 3, 5: res := 1 |
    2, 4, 6: res := 2
  END;
  Out.Int(res, 0); Out.Ln;
  x := 7;
  CASE x OF
    0..5: res := 1 |
    6..10: res := 2 |
    11..20: res := 3
  END;
  Out.Int(res, 0); Out.Ln;
  ch := 'B';
  CASE ORD(ch) OF
    65: res := 1 |
    66: res := 2 |
    67: res := 3
  END;
  Out.Int(res, 0); Out.Ln;
  x := -1;
  CASE x OF
    -2: res := 1 |
    -1: res := 2 |
    0: res := 3
  END;
  Out.Int(res, 0); Out.Ln;
  x := 1;
  CASE x OF
    1: res := 100 |
    2: res := 200 |
    3: res := 300
  END;
  Out.Int(res, 0); Out.Ln;
  x := 3;
  CASE x OF
    1: res := 100 |
    2: res := 200 |
    3: res := 300
  END;
  Out.Int(res, 0); Out.Ln
END CaseBasic;

PROCEDURE CaseAdvPart;
VAR x, res: INTEGER;
BEGIN
  x := 50;
  CASE x OF
    0..25: res := 1
  | 26..50: res := 2
  | 51..100: res := 3
  END;
  Out.Int(res, 0); Out.Ln;
  x := 0;
  CASE x OF
    0..10: res := 10
  | 11..20: res := 20
  END;
  Out.Int(res, 0); Out.Ln;
  x := 10;
  CASE x OF
    0..10: res := 10
  | 11..20: res := 20
  END;
  Out.Int(res, 0); Out.Ln;
  x := 7;
  CASE x OF
    1, 3, 5: res := 1
  | 2, 4, 6: res := 2
  | 7..10: res := 3
  END;
  Out.Int(res, 0); Out.Ln;
  res := -1;
  x := 1;
  CASE x OF
    1: res := -1
  | 2: res := 2
  END;
  Out.Int(res, 0); Out.Ln;
  x := 3;
  CASE x OF
    1: res := 10
  | 2: res := 20
  | 3: res := 30
  END;
  Out.Int(res, 0); Out.Char(' ');
  x := 1;
  CASE x OF
    1: res := 100
  | 2: res := 200
  | 3: res := 300
  END;
  Out.Int(res, 0); Out.Ln;
  FOR x := 1 TO 4 DO
    CASE x OF
      1: Out.Char('A')
    | 2: Out.Char('B')
    | 3: Out.Char('C')
    | 4: Out.Char('D')
    END
  END;
  Out.Ln;
  x := -3;
  CASE x OF
    -5..-1: res := 1
  | 0..5: res := 2
  END;
  Out.Int(res, 0); Out.Ln
END CaseAdvPart;

PROCEDURE CaseNestPart;
VAR x, y, res: INTEGER;
BEGIN
  x := 2; y := 3;
  CASE x OF
    1: CASE y OF
         1: res := 11
       | 2: res := 12
       | 3: res := 13
       END
  | 2: CASE y OF
         1: res := 21
       | 2: res := 22
       | 3: res := 23
       END
  | 3: res := 30
  END;
  Out.Int(res, 0); Out.Ln;
  x := 1; y := 2;
  CASE x OF
    1: CASE y OF
         1: res := 100
       | 2: res := 200
       END
  | 2: res := 999
  END;
  Out.Int(res, 0); Out.Ln;
  x := 3; y := 1;
  CASE x OF
    1: res := 0
  | 2: res := 0
  | 3: CASE y OF
         1: res := 31
       | 2: res := 32
       END
  END;
  Out.Int(res, 0); Out.Ln;
  x := 1; y := 2;
  CASE x OF
    1: CASE y OF
         1: res := 0
       | 2: CASE x + y OF
              3: res := 123
            | 4: res := 124
            END
       END
  | 2: res := 0
  END;
  Out.Int(res, 0); Out.Ln;
  x := 5; y := 15;
  CASE x OF
    1..5: CASE y OF
            1..10: res := 1
          | 11..20: res := 2
          END
  | 6..10: res := 3
  END;
  Out.Int(res, 0); Out.Ln;
  FOR x := 1 TO 3 DO
    CASE x OF
      1: CASE x + 10 OF
           11: Out.Char('A')
         | 12: Out.Char('?')
         END
    | 2: CASE x * 2 OF
           4: Out.Char('B')
         | 5: Out.Char('?')
         END
    | 3: Out.Char('C')
    END
  END;
  Out.Ln
END CaseNestPart;

BEGIN
  CaseBasic; CaseAdvPart; CaseNestPart
END SuiteCase.
