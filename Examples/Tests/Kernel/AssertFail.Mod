MODULE AssertFail;

PROCEDURE TestAssert;
BEGIN
  ASSERT
    (FALSE)
END TestAssert;

BEGIN
  TestAssert
END AssertFail.
