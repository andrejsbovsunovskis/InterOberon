#!/bin/bash
# Test runner for InterOberon compiler
# Compiles and runs each test, comparing output with expected results

cd "$(dirname "$0")"
COMPILER=./InterOberon
OUTDIR=bin
PASS=0
FAIL=0
ERRORS=""

run_test() {
    local src="$1"
    local expected="$2"
    local name=$(basename "$src" .Mod)
    
    # Compile
    output=$($COMPILER -o "$OUTDIR/" "$src" 2>&1)
    if [ $? -ne 0 ]; then
        echo "FAIL [compile] $name"
        echo "  Compiler output: $output"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: compile error"
        return
    fi
    
    # Run ($(...) strips trailing newlines from stdout; preserve them)
    local tmp
    tmp=$(mktemp)
    set +e
    "$OUTDIR/$name" >"$tmp" 2>&1
    rc=$?
    set -e
    actual=$(cat "$tmp"; printf x)
    actual=${actual%x}
    rm -f "$tmp"

    if [ $rc -ne 0 ]; then
        echo "FAIL [crash] $name (exit code $rc)"
        echo "  Output before crash: $(echo "$actual" | tail -3)"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: crash (exit $rc)"
        return
    fi

    if [ "$actual" = "$expected" ]; then
        echo "PASS $name"
        PASS=$((PASS + 1))
    else
        echo "FAIL [output] $name"
        echo "  Expected: $(echo "$expected" | head -3)..."
        echo "  Actual:   $(echo "$actual" | head -3)..."
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: output mismatch"
    fi
}

# Like run_test, but feeds stdin (printf '%b' "$stdin_data" | program).
run_test_stdin() {
    local src="$1"
    local stdin_data="$2"
    local expected="$3"
    local name=$(basename "$src" .Mod)

    output=$($COMPILER -o "$OUTDIR/" "$src" 2>&1)
    if [ $? -ne 0 ]; then
        echo "FAIL [compile] $name"
        echo "  Compiler output: $output"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: compile error"
        return
    fi

    # Bash $(...) strips trailing newlines from command output; preserve them.
    local tmp
    tmp=$(mktemp)
    set +e
    printf '%b' "$stdin_data" | "$OUTDIR/$name" >"$tmp" 2>&1
    rc=$?
    set -e
    actual=$(cat "$tmp"; printf x)
    actual=${actual%x}
    rm -f "$tmp"

    if [ $rc -ne 0 ]; then
        echo "FAIL [crash] $name (exit code $rc)"
        echo "  Output before crash: $(echo "$actual" | tail -3)"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: crash (exit $rc)"
        return
    fi

    if [ "$actual" = "$expected" ]; then
        echo "PASS $name"
        PASS=$((PASS + 1))
    else
        echo "FAIL [output] $name"
        echo "  Expected: $(echo "$expected" | head -3)..."
        echo "  Actual:   $(echo "$actual" | head -3)..."
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: output mismatch"
    fi
}

run_test_expected_file() {
    local src="$1"
    local expfile="$2"
    local expected
    expected=$(cat "$expfile"; printf x)
    expected=${expected%x}
    run_test "$src" "$expected"
}

run_test_stdin_expected_file() {
    local src="$1"
    local stdin_data="$2"
    local expfile="$3"
    local expected
    expected=$(cat "$expfile"; printf x)
    expected=${expected%x}
    run_test_stdin "$src" "$stdin_data" "$expected"
}

mkdir -p "$OUTDIR"

echo "========================================"
echo "  InterOberon Test Suite"
echo "========================================"
echo ""

make

EXP=Examples/Tests/expected

# --- Combined suites (replace many small modules; expected/*.txt from golden output) ---
run_test_expected_file "Examples/Tests/SuiteBoolCmpChar.Mod" "$EXP/SuiteBoolCmpChar.txt"
run_test_expected_file "Examples/Tests/SuiteByteShift.Mod" "$EXP/SuiteByteShift.txt"
run_test_expected_file "Examples/Tests/SuiteArrayMD.Mod" "$EXP/SuiteArrayMD.txt"
run_test_expected_file "Examples/Tests/SuiteReal.Mod" "$EXP/SuiteReal.txt"
run_test_expected_file "Examples/Tests/SuiteCase.Mod" "$EXP/SuiteCase.txt"
run_test_expected_file "Examples/Tests/SuiteFlow.Mod" "$EXP/SuiteFlow.txt"
run_test_expected_file "Examples/Tests/SuiteProc.Mod" "$EXP/SuiteProc.txt"
run_test_expected_file "Examples/Tests/SuiteSet.Mod" "$EXP/SuiteSet.txt"
run_test_expected_file "Examples/Tests/SuiteTypeMix.Mod" "$EXP/SuiteTypeMix.txt"
run_test_expected_file "Examples/Tests/SuiteArr.Mod" "$EXP/SuiteArr.txt"
run_test_expected_file "Examples/Tests/SuiteNum.Mod" "$EXP/SuiteNum.txt"
run_test_expected_file "Examples/Tests/BuiltinCond.Mod" "$EXP/BuiltinCond.txt"

run_test_stdin_expected_file "Examples/Tests/SuiteStrIn.Mod" \
  $'A\xd0\xaf\xe2\x82\xac\n \t777\n-17\n  0\n999999\nHello\n\xd0\x9f\xd1\x80\xd0\xb8\xd0\xb2\xd0\xb5\xd1\x82\n\nab\r\nLineA\nLineB\n' \
  "$EXP/SuiteStrIn.txt"

run_test_expected_file "Examples/Tests/InclExcl.Mod" "$EXP/InclExcl.txt"

# --- Open arrays (large, kept separate) ---
run_test_expected_file "Examples/Tests/OpenArr.Mod" "$EXP/OpenArr.txt"
run_test_expected_file "Examples/Tests/OpenMD.Mod" "$EXP/OpenMD.txt"

echo ""
echo "========================================"
printf "  Results: %d passed, %d failed out of %d total\n" $PASS $FAIL $((PASS + FAIL))
echo "========================================"
if [ $FAIL -gt 0 ]; then
    echo -e "  Failed tests:$ERRORS"
    echo ""
fi
