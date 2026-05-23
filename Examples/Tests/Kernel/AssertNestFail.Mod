MODULE AssertNestFail;

PROCEDURE Outer;

  PROCEDURE Inner;
  BEGIN
    ASSERT(FALSE)
  END Inner;

BEGIN
  Inner
END Outer;

BEGIN
  Outer
END AssertNestFail.
