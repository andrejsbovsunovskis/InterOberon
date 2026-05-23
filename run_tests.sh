#!/bin/bash
# Test runner for InterOberon compiler
# Compiles and runs each test, comparing output with expected results

cd "$(dirname "$0")"
COMPILER=./InterOberon
OUTDIR=bin
PASS=0
FAIL=0
ERRORS=""
RUN_TIMEOUT="${RUN_TIMEOUT:-30}"

# Run a program; kill it if it exceeds RUN_TIMEOUT seconds.
run_timed() {
    local secs=$1; shift
    "$@" &
    local pid=$!
    ( sleep "$secs" && kill -9 "$pid" 2>/dev/null ) &
    local sp=$!
    wait "$pid" 2>/dev/null
    local rc=$?
    kill "$sp" 2>/dev/null
    wait "$sp" 2>/dev/null
    if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        return 124
    fi
    return $rc
}

# Foreground + timeout: stdin pipe does not reach a background job.
run_timed_stdin() {
    local secs=$1; shift
    perl -e '
        $t = shift;
        $pid = fork();
        if ($pid == 0) { exec @ARGV or exit 1 }
        $SIG{ALRM} = sub { kill 9, $pid; waitpid($pid, 0); exit 124 };
        alarm $t;
        waitpid($pid, 0);
        alarm 0;
        $s = ($? >> 8);
        exit (($s == 9) || ($s == 137)) ? 124 : $s;
    ' "$secs" "$@"
}

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
    run_timed "$RUN_TIMEOUT" "$OUTDIR/$name" >"$tmp" 2>&1
    rc=$?
    actual=$(cat "$tmp"; printf x)
    actual=${actual%x}
    rm -f "$tmp"

    if [ $rc -eq 124 ] || [ $rc -eq 137 ]; then
        echo "FAIL [timeout] $name (>${RUN_TIMEOUT}s)"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: timeout (>${RUN_TIMEOUT}s)"
        return
    fi

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
    printf '%b' "$stdin_data" | run_timed_stdin "$RUN_TIMEOUT" "$OUTDIR/$name" >"$tmp" 2>&1
    rc=$?
    actual=$(cat "$tmp"; printf x)
    actual=${actual%x}
    rm -f "$tmp"

    if [ $rc -eq 124 ] || [ $rc -eq 137 ]; then
        echo "FAIL [timeout] $name (>${RUN_TIMEOUT}s)"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: timeout (>${RUN_TIMEOUT}s)"
        return
    fi

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

# Expect program to abort with a given exit code and stderr/stdout message.
run_test_abort() {
    local src="$1"
    local expected_rc="$2"
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

    local tmp
    tmp=$(mktemp)
    set +e
    run_timed "$RUN_TIMEOUT" "$OUTDIR/$name" >"$tmp" 2>&1
    rc=$?
    actual=$(cat "$tmp"; printf x)
    actual=${actual%x}
    rm -f "$tmp"

    if [ $rc -eq 124 ] || [ $rc -eq 137 ]; then
        echo "FAIL [timeout] $name (>${RUN_TIMEOUT}s)"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: timeout (>${RUN_TIMEOUT}s)"
        return
    fi

    if [ $rc -ne "$expected_rc" ]; then
        echo "FAIL [abort] $name (exit code $rc, expected $expected_rc)"
        echo "  Output: $(echo "$actual" | head -3)"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: abort exit $rc"
        return
    fi

    if [ "$actual" = "$expected" ]; then
        echo "PASS $name (abort expected)"
        PASS=$((PASS + 1))
    else
        echo "FAIL [abort output] $name"
        echo "  Expected: $(echo "$expected" | head -3)"
        echo "  Actual:   $(echo "$actual" | head -3)"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: abort output mismatch"
    fi
}

# Expect compilation to fail (negative test).
run_compile_fail() {
    local src="$1"
    local name=$(basename "$src" .Mod)
    output=$($COMPILER -o "$OUTDIR/" "$src" 2>&1)
    local rc=$?
    if [ $rc -eq 139 ] || [ $rc -eq 134 ] || [ $rc -eq 11 ]; then
        echo "FAIL [SEGV] $name"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: compiler crashed (exit $rc)"
    elif [ $rc -ne 0 ]; then
        echo "PASS $name (compile fail expected)"
        PASS=$((PASS + 1))
    else
        echo "FAIL [should not compile] $name"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: compiled but should have failed"
    fi
}

mkdir -p "$OUTDIR"

echo "========================================"
echo "  InterOberon Test Suite"
echo "========================================"
echo ""

make
make lib

EXP=Examples/Tests/expected
TS=Examples/Tests
SU=$TS/Suite
IO=$TS/IO
LIB=$TS/Lib
TR=$TS/Trans
OP=$TS/Open
KR=$TS/Kernel
MT=$TS/MultiTest
PT=$TS/PartTrans
DEEP=$TS/Deep
RUN_DEEP="${RUN_DEEP:-1}"

# --- Lib: Strings, Files, translations ---
LIB_EXP=$LIB/expected
for s in "$LIB"/Suite*.Mod; do
    base=$(basename "$s" .Mod)
    run_test_expected_file "$s" "$LIB_EXP/$base.txt"
done
if [ -x ./showdef ]; then
    out=$(./showdef --lang ru Strings 2>&1)
    if echo "$out" | grep -q 'Позиция' && echo "$out" | grep -q 'ВерхнийРегистр'; then
        echo "PASS showdef-strings-ru"
        PASS=$((PASS + 1))
    else
        echo "FAIL showdef-strings-ru"
        FAIL=$((FAIL + 1))
    fi
    out=$(./showdef --lang lv Strings 2>&1)
    if echo "$out" | grep -q 'Pozīcija' && echo "$out" | grep -q 'LielieBurti'; then
        echo "PASS showdef-strings-lv"
        PASS=$((PASS + 1))
    else
        echo "FAIL showdef-strings-lv"
        FAIL=$((FAIL + 1))
    fi
    out=$(./showdef --lang ru Files 2>&1)
    if echo "$out" | grep -q 'ЧитатьЦелое' && echo "$out" | grep -q 'Зарегистрировать'; then
        echo "PASS showdef-files-ru"
        PASS=$((PASS + 1))
    else
        echo "FAIL showdef-files-ru"
        FAIL=$((FAIL + 1))
    fi
    out=$(./showdef --lang lv Files 2>&1)
    if echo "$out" | grep -q 'LasītVesels' && echo "$out" | grep -q 'Reģistrēt'; then
        echo "PASS showdef-files-lv"
        PASS=$((PASS + 1))
    else
        echo "FAIL showdef-files-lv"
        FAIL=$((FAIL + 1))
    fi
else
    echo "SKIP showdef-strings-i18n (not built)"
fi

# --- Suite: language/runtime coverage ---
for s in "$SU"/Suite*.Mod "$SU"/BuiltinCond.Mod; do
    base=$(basename "$s" .Mod)
    run_test_expected_file "$s" "$EXP/$base.txt"
done

run_test_stdin_expected_file "$IO/SuiteStrIn.Mod" \
  $'A\xd0\xaf\xe2\x82\xac\xf0\x9f\x98\x80\n \t777\n-17\n  0\n999999\nHello\n\xd0\x9f\xd1\x80\xd0\xb8\xd0\xb2\xd0\xb5\xd1\x82\n\nab\r\nLineA\nLineB\n' \
  "$EXP/SuiteStrIn.txt"

run_test_expected_file "$IO/OutFull.Mod" "$EXP/OutFull.txt"

# --- Compile-fail tests (Neg*.Mod in Suite, Trans, Kernel) ---
run_compile_fail_dir() {
    local d neg
    for neg in "$1"/Neg*.Mod; do
        [ -f "$neg" ] && run_compile_fail "$neg"
    done
}
run_compile_fail_dir "$SU"
for neg in "$TR"/NegFormalTrans*.Mod; do
    [ -f "$neg" ] && run_compile_fail "$neg"
done
run_compile_fail_dir "$KR"

# --- Deep: extended language regression ---
if [ "$RUN_DEEP" = 1 ]; then
    DEEP_EXP=$DEEP/expected
    for s in "$DEEP"/Deep*.Mod; do
        [ -f "$s" ] || continue
        base=$(basename "$s" .Mod)
        run_test_expected_file "$s" "$DEEP_EXP/$base.txt"
    done
    if [ -d "$DEEP/NegDeep" ]; then
        run_compile_fail_dir "$DEEP/NegDeep"
    fi
fi

# --- ASSERT runtime failure ---
KR_EXP=$KR/expected
abort_expected=$(cat "$KR_EXP/AssertFail.txt"; printf x)
abort_expected=${abort_expected%x}
run_test_abort "$KR/AssertFail.Mod" 1 "$abort_expected"

abort_n_expected=$(cat "$KR_EXP/AssertFailN.txt"; printf x)
abort_n_expected=${abort_n_expected%x}
run_test_abort "$KR/AssertFailN.Mod" 42 "$abort_n_expected"

abort_nest_expected=$(cat "$KR_EXP/AssertNestFail.txt"; printf x)
abort_nest_expected=${abort_nest_expected%x}
run_test_abort "$KR/AssertNestFail.Mod" 1 "$abort_nest_expected"

# ASSERT stripped with --no-assert
run_test_no_assert() {
    local src="$1"
    local name=$(basename "$src" .Mod)
    output=$($COMPILER --no-assert -o "$OUTDIR/" "$src" 2>&1)
    if [ $? -ne 0 ]; then
        echo "FAIL [compile --no-assert] $name"
        FAIL=$((FAIL + 1))
        return
    fi
    set +e
    "$OUTDIR/$name" >/dev/null 2>&1
    rc=$?
    set -e
    if [ $rc -eq 0 ]; then
        PASS=$((PASS + 1))
    else
        echo "FAIL [--no-assert] $name (exit $rc, expected 0)"
        FAIL=$((FAIL + 1))
    fi
}
run_test_no_assert "$KR/AssertFail.Mod"

run_test_stdin_expected_file "$IO/InFull.Mod" \
  $'A42 255 -7\n12345 -32000\n\xd0\xbf\xd1\x83\xd1\x82\xd1\x8c/\xd1\x84\xd0\xb0\xd0\xb9\xd0\xbb \xd1\x84\xd0\xb0\xd0\xb9\xd0\xbb LONGabcdefgh\n\x27apple\x27 "banana"\nafter strings\nLONGabcdefgh\nnextline\nunquoted\n 1.5\n-2.5e-1\n3.0\n' \
  "$EXP/InFull.txt"
run_test_expected_file "$IO/OutRu.Mod" "$EXP/OutRu.txt"
run_test_expected_file "$IO/OutLv.Mod" "$EXP/OutLv.txt"
run_test_stdin_expected_file "$IO/InRu.Mod" \
  $'Z 42 -17 hello world\n\n\xd0\xad\xd1\x82\xd0\xbe \xd1\x81\xd1\x82\xd1\x80\xd0\xbe\xd0\xba\xd0\xb0\n3.5\n' \
  "$EXP/InRu.txt"
run_test_stdin_expected_file "$IO/InLv.Mod" \
  $'M 42 -17 hello world\n\xc5\xa0\xc4\xab ir rinda\n3.5\n' \
  "$EXP/InLv.txt"

run_test_expected_file "$TR/FormalTrans.Mod" "$EXP/FormalTrans.txt"
run_test_expected_file "$TR/FormalTransRu.Mod" "$EXP/FormalTransRu.txt"
run_test_expected_file "$TR/FormalTransBox.Mod" "$EXP/FormalTransBox.txt"

# --- Open arrays ---
run_test_expected_file "$OP/OpenArr.Mod" "$EXP/OpenArr.txt"
run_test_expected_file "$OP/OpenMD.Mod" "$EXP/OpenMD.txt"

# --- Multi-module tests ---

run_multi_test() {
    local name="$1"; shift
    local expfile="$1"; shift
    local exe="$1"; shift
    local expected
    expected=$(cat "$expfile"; printf x)
    expected=${expected%x}

    output=$($COMPILER -o "$OUTDIR/" "$@" 2>&1)
    if [ $? -ne 0 ]; then
        echo "FAIL [compile] $name"
        echo "  Compiler output: $output"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: compile error"
        return
    fi

    local tmp; tmp=$(mktemp)
    set +e
    run_timed "$RUN_TIMEOUT" "$OUTDIR/$exe" >"$tmp" 2>&1
    rc=$?
    actual=$(cat "$tmp"; printf x); actual=${actual%x}
    rm -f "$tmp"

    if [ $rc -eq 124 ] || [ $rc -eq 137 ]; then
        echo "FAIL [timeout] $name (>${RUN_TIMEOUT}s)"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: timeout (>${RUN_TIMEOUT}s)"
        return
    fi

    if [ $rc -ne 0 ]; then
        echo "FAIL [crash] $name (exit code $rc)"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: crash (exit $rc)"
        return
    fi

    if [ "$actual" = "$expected" ]; then
        echo "PASS $name"
        PASS=$((PASS + 1))
    else
        echo "FAIL [output] $name"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: output mismatch"
    fi
}

run_multi_test "MultiTest:Main.Run" "$MT/expected/Main.txt" "Main" \
    "$MT/Main.Mod" "Main.Run"

run_multi_test "MultiTest:--cmd" "$MT/expected/Main.txt" "Main" \
    "$MT/Main.Mod" --cmd "Main.Run"

run_multi_test "MultiTest:short-cmd" "$MT/expected/Main.txt" "Main" \
    "$MT/Main.Mod" "Run"

run_multi_test "MultiTest:inferred-ext" "$MT/expected/Main.txt" "Main" \
    "$MT/Main.Run"

run_multi_test "MultiTest:init-only" "$MT/expected/InitOnly.txt" "InitOnly" \
    "$MT/InitOnly.Mod"

run_multi_test "MultiTest:--exact" "$MT/expected/Main.txt" "Main" \
    --exact "$MT/Main.Mod" "Main.Run"

run_multi_test "MultiTest:PtrMain" "$MT/expected/PtrMain.txt" "PtrMain" \
    "$MT/PtrMain.Mod" "PtrMain.Run"

run_multi_test "MultiTest:ExtMain" "$MT/expected/ExtMain.txt" "ExtMain" \
    "$MT/ExtMain.Mod" "ExtMain.Run"

run_multi_test "MultiTest:DataUse" "$MT/expected/DataUse.txt" "DataUse" \
    "$MT/DataUse.Mod" "DataUse.Run"

run_multi_test "MultiTest:ShadowUtf8" "$MT/expected/ShadowMain.txt" "ShadowMain" \
    "$MT/ShadowMain.Mod" "ShadowMain.Run"

$COMPILER -c -o "$OUTDIR/" "$PT/PartCore.Mod" >/dev/null 2>&1

run_multi_test "PartTrans:Ru" "$PT/expected/PartRu.txt" "PartRu" \
    "$PT/PartRu.Mod"

run_multi_test "PartTrans:Lv" "$PT/expected/PartLv.txt" "PartLv" \
    "$PT/PartLv.Mod"

echo ""
echo "--- showdef ---"
if [ -x ./showdef ]; then
    $COMPILER -c -o "$OUTDIR/" "$TR/ShowDefPtr.Mod" >/dev/null 2>&1
    $COMPILER -c -o "$OUTDIR/" "$TR/FormalTransMini.Mod" >/dev/null 2>&1
    $COMPILER -c -o "$OUTDIR/" "$TR/ShowDefTrans.Mod" >/dev/null 2>&1
    $COMPILER -c -o "$OUTDIR/" "$TR/NegAnonRecExport.Mod" >/dev/null 2>&1
    out=$(./showdef ShowDefPtr 2>&1)
    if echo "$out" | grep -q 'DEFINITION' && echo "$out" | grep -q '#VariantDesc'; then
        echo "PASS showdef-ptr"
        PASS=$((PASS + 1))
    else
        echo "FAIL showdef-ptr"
        FAIL=$((FAIL + 1))
    fi
    out=$(./showdef --lang ru FormalTransMini 2>&1)
    if echo "$out" | grep -q 'ОПРЕДЕЛЕНИЕ' && echo "$out" | grep -q 'МойТип'; then
        echo "PASS showdef-ru"
        PASS=$((PASS + 1))
    else
        echo "FAIL showdef-ru"
        FAIL=$((FAIL + 1))
    fi
    $COMPILER -c -o "$OUTDIR/" "$PT/PartCore.Mod" >/dev/null 2>&1
    out=$(./showdef --lang ru FormalTransMini PartCore -d "$OUTDIR/" 2>&1)
    if echo "$out" | grep -q 'ОПРЕДЕЛЕНИЕ Мини' && echo "$out" | grep -q 'ОПРЕДЕЛЕНИЕ Ядро' &&
       echo "$out" | grep -q 'КОНЕЦ Мини' && echo "$out" | grep -q 'КОНЕЦ Ядро'; then
        echo "PASS showdef-multi"
        PASS=$((PASS + 1))
    else
        echo "FAIL showdef-multi"
        FAIL=$((FAIL + 1))
    fi
    out=$(./showdef --lang ru ShowDefTrans 2>&1)
    if echo "$out" | grep -q 'ОПРЕДЕЛЕНИЕ' && echo "$out" | grep -q 'Транс'; then
        echo "PASS showdef-trans"
        PASS=$((PASS + 1))
    else
        echo "FAIL showdef-trans"
        FAIL=$((FAIL + 1))
    fi
    out=$(./showdef NegAnonRecExport 2>&1)
    if [ $? -eq 0 ] && echo "$out" | grep -q 'PROCEDURE U' && echo "$out" | grep -q 'RECORD'; then
        echo "PASS showdef-anon-rec"
        PASS=$((PASS + 1))
    else
        echo "FAIL showdef-anon-rec"
        FAIL=$((FAIL + 1))
    fi
    out=$(./showdef --langs FormalTransMini 2>&1 | tr '\n' ' ')
    if echo "$out" | grep -q 'en' && echo "$out" | grep -q 'ru'; then
        echo "PASS showdef-langs"
        PASS=$((PASS + 1))
    else
        echo "FAIL showdef-langs"
        FAIL=$((FAIL + 1))
    fi
    out=$(./showdef -a FormalTransMini 2>&1)
    if echo "$out" | grep -q '%EN:' && echo "$out" | grep -q '%RU:'; then
        echo "PASS showdef-all"
        PASS=$((PASS + 1))
    else
        echo "FAIL showdef-all"
        FAIL=$((FAIL + 1))
    fi
    out=$(./showdef --lang ru -d "$OUTDIR/" PartCore 2>&1)
    if echo "$out" | grep -q 'ОПРЕДЕЛЕНИЕ Ядро' && echo "$out" | grep -q 'Альфа' &&
       echo "$out" | grep -q 'Beta' && echo "$out" | grep -q 'SetTotal' &&
       echo "$out" | grep -q 'База = 10'; then
        echo "PASS showdef-part-ru"
        PASS=$((PASS + 1))
    else
        echo "FAIL showdef-part-ru"
        FAIL=$((FAIL + 1))
    fi
    out=$(./showdef --lang lv -d "$OUTDIR/" PartCore 2>&1)
    if echo "$out" | grep -q 'DEFINĪCIJA Kodols' && echo "$out" | grep -q 'IestatTot' &&
       echo "$out" | grep -q 'Alpha' && echo "$out" | grep -q 'Baze = 10'; then
        echo "PASS showdef-part-lv"
        PASS=$((PASS + 1))
    else
        echo "FAIL showdef-part-lv"
        FAIL=$((FAIL + 1))
    fi
    out=$(./showdef --langs -d "$OUTDIR/" PartCore 2>&1 | tr '\n' ' ')
    if echo "$out" | grep -q 'en' && echo "$out" | grep -q 'ru' &&
       echo "$out" | grep -q 'lv'; then
        echo "PASS showdef-part-langs"
        PASS=$((PASS + 1))
    else
        echo "FAIL showdef-part-langs"
        FAIL=$((FAIL + 1))
    fi
    out=$(./showdef -a -d "$OUTDIR/" PartCore 2>&1)
    if echo "$out" | grep -q '%RU:Альфа' && echo "$out" | grep -q '%LV:IestatTot'; then
        echo "PASS showdef-part-all"
        PASS=$((PASS + 1))
    else
        echo "FAIL showdef-part-all"
        FAIL=$((FAIL + 1))
    fi
else
    echo "SKIP showdef (not built)"
fi

echo ""
echo "========================================"
printf "  Results: %d passed, %d failed out of %d total\n" $PASS $FAIL $((PASS + FAIL))
echo "========================================"
if [ $FAIL -gt 0 ]; then
    echo -e "  Failed tests:$ERRORS"
    echo ""
fi
