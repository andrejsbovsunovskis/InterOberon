MODULE PartCore; (**%RU:Ядро%LV:Kodols*)

IMPORT Out;

CONST
  Base* = 10; (**%RU:База%LV:Baze*)

TYPE
  Item* = INTEGER; (**%RU:Пункт%LV:Punkts*)

VAR
  total*: INTEGER; (**%RU:сумма%LV:kops*)

PROCEDURE Alpha*(x: Item): Item; (**%RU:Альфа*)
BEGIN RETURN x + Base END Alpha;

PROCEDURE Beta*(x: Item): Item;
BEGIN RETURN x + 1 END Beta;

PROCEDURE SetTotal*(n: INTEGER); (**%LV:IestatTot*)
BEGIN total := n END SetTotal;

PROCEDURE ShowTotal*;
BEGIN Out.Int(total, 0); Out.Ln END ShowTotal;

BEGIN
  total := 0
END PartCore.
