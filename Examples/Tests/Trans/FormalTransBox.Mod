MODULE FormalTransBox; (**%RU:КоробкаТест%LV:KasteTests*)

IMPORT Out;

TYPE
  Box* = POINTER TO BoxDesc; (**%RU:Коробка%LV:Kaste*)
  BoxDesc* = RECORD (**%RU:ОписаниеКоробки%LV:KastesApraksts*)
    point: RECORD x, y: REAL END;
    params: RECORD weight, size: REAL END;
  END;

VAR b: Box;

BEGIN
  Out.Int(0, 0); Out.Ln
END FormalTransBox.
