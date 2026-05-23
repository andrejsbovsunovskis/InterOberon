MODULIS OutLv;
(* Smoke: translated Out names from Lib/Out %LV comments. *)
IMPORTĒ Izvade;

MAINĪGIE i: VESELAIS;
  x: REĀLAIS;
SĀKUMS
  Izvade.Atvērt;
  Izvade.Virkne('--- Litera un Virkne ---'); Izvade.Pārnese;
  Izvade.Litera('S'); Izvade.Litera('v'); Izvade.Litera('e');
  Izvade.Litera('i'); Izvade.Litera('k'); Izvade.Litera('i');
  Izvade.Litera('!'); Izvade.Pārnese;
  Izvade.Virkne('Sveiki, pasaule!'); Izvade.Pārnese;

  Izvade.Virkne('--- Veselais ---'); Izvade.Pārnese;
  i := 0;
  KAMĒR i < 5 DARĪT
    Izvade.Veselais(i, 3); Izvade.Litera(' '); PALIEL(i)
  BEIGAS;
  Izvade.Pārnese;
  Izvade.Veselais(-42, 0); Izvade.Pārnese;
  Izvade.Veselais(2025, 6); Izvade.Pārnese;

  Izvade.Virkne('--- Heks ---'); Izvade.Pārnese;
  Izvade.Heks(255, 0); Izvade.Pārnese;
  Izvade.Heks(255, 4); Izvade.Pārnese;

  Izvade.Virkne('--- Reālais / ReālaisFix / GaraisReālais ---'); Izvade.Pārnese;
  x := 1.5;
  Izvade.Reālais(x, 0); Izvade.Pārnese;
  Izvade.ReālaisFix(x, 0, 2); Izvade.Pārnese;
  Izvade.ReālaisFix(-x, 0, 3); Izvade.Pārnese;
  Izvade.GaraisReālais(0.25, 0); Izvade.Pārnese;
  Izvade.GaraisReālaisFix(0.25, 0, 4); Izvade.Pārnese;

  Izvade.Iztukšot
BEIGAS OutLv.
