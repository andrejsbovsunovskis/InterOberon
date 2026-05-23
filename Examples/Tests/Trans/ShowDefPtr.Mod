MODULE ShowDefPtr;

TYPE
  Variant* = POINTER TO VariantDesc;
  VariantDesc = RECORD
    v: INTEGER
  END;

END ShowDefPtr.
