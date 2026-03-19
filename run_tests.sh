#!/bin/bash
# Test runner for InterOberon compiler
# Compiles and runs each test, comparing output with expected results

cd "$(dirname "$0")"
COMPILER=./InterOberon
PASS=0
FAIL=0
ERRORS=""

run_test() {
    local src="$1"
    local expected="$2"
    local name=$(basename "$src" .Mod)
    
    # Compile
    output=$($COMPILER "$src" 2>&1)
    if [ $? -ne 0 ]; then
        echo "FAIL [compile] $name"
        echo "  Compiler output: $output"
        FAIL=$((FAIL + 1))
        ERRORS="$ERRORS\n  $name: compile error"
        return
    fi
    
    # Run
    actual=$(./"$name" 2>&1)
    rc=$?
    
    # Clean up
    rm -f "$name" "$name.obj" "$name.sym" 2>/dev/null
    
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

echo "========================================"
echo "  InterOberon Test Suite"
echo "========================================"
echo ""

# ===================== NEW TESTS =====================

# --- ArithTest: arithmetic operations ---
run_test "Examples/Tests/ArithTest.Mod" "10
7
42
3
2
-42
5
14
20
1000000
142857
6
0
77
5
42
99
0
1
0
11
15
9
7
25"

# --- BoolTest: boolean logic ---
run_test "Examples/Tests/BoolTest.Mod" "1
0
0
1
1
0
0
0
1
1
1
0
1
0
1
0
0
0
0
0"

# --- CharTest: character operations ---
run_test "Examples/Tests/CharTest.Mod" "A
Z
65
48
B
90
1
1
1
0123456789
abcdef
1
32
H
B"

# --- CompTest: comparisons ---
run_test "Examples/Tests/CompTest.Mod" "1
1
1
1
1
1
0
1
1
1
1
1
1
1
1"

# --- NestLoop: nested loops ---
run_test "Examples/Tests/NestLoop.Mod" "123
246
369
100
*
**
***
****
*****
.
..
...
0 3 6 9 12 15 18 
321 21 1 
385
21"

# --- Array2: array operations ---
run_test "Examples/Tests/Array2.Mod" "20
80 70 60 50 40 30 20 10 
0 1 2 3 4 5 6 7 8 9 
HELLO
55
89
7
3"

# --- CaseAdv: advanced CASE ---
run_test "Examples/Tests/CaseAdv.Mod" "2
10
10
3
-1
30 100
ABCD
1"

# --- SetAdv: advanced SET ---
run_test "Examples/Tests/SetAdv.Mod" "0
21
17
1
0
32
3075
170
5
102
42
0"

# --- RealAdv: advanced REAL ---
run_test "Examples/Tests/RealAdv.Mod" "1
3
3
-2
11111
1
256
33
7
1000000"

# --- MixType: mixed types ---
run_test "Examples/Tests/MixType.Mod" "127
999999
200
42
80
-100
2000000
2000000
255
0
1
1
33
3
1000"

# --- Algo: algorithms ---
run_test "Examples/Tests/Algo.Mod" "6
3628800
1 1 2 3 5 8 13 21 
1024
15
4321
10
3
1 3 5 7 9 
111"

# --- OutFmt: output formatting ---
run_test "Examples/Tests/OutFmt.Mod" "42
-7
0
123456
[99]
--------------------
1:1
2:4
3:9
4:16
5:25
ABCDEFGHIJ
(1+2=3)
111
222
333"

# --- EdgeCase: edge cases ---
run_test "Examples/Tests/EdgeCase.Mod" "2147483647
-2147483648
0
0
0
777
0
1
1
0
1
-1
-42
55
999"

# =================== EXISTING TESTS ===================

# --- IfTest ---
run_test "Examples/Tests/IfTest.Mod" "1
0
100
200
10
20
30
99
1
2
1
0
1
1
0
3
31
1
7
2
OK"

# --- ForTest ---
run_test "Examples/Tests/ForTest.Mod" "0 1 2 3 4 5 
0 2 4 6 8 10 
5 4 3 2 1 0 
5050
1 2 3 
99
7"

# --- WhileTest ---
run_test "Examples/Tests/WhileTest.Mod" "15
33
222
60
99
102
24
38
6
1111
35
10
OK"

# --- ArrayTest ---
run_test "Examples/Tests/ArrayTest.Mod" "149162536496481100
385"

# --- ByteTest ---
run_test "Examples/Tests/ByteTest.Mod" "42
30
255
100
120
1
1
0
16
100"

# --- ShiftTest ---
run_test "Examples/Tests/ShiftTest.Mod" "16
768
16
128
-4
40
20
7
42
99
1024
64
16
1048576
1
32
OK"

# --- SetTest ---
run_test "Examples/Tests/SetTest.Mod" "0
1
8
7
15
240
15
6
5
9
1
0
8
13
1
1
15
12
1
21
126
21
9
4"

# --- CaseTest ---
run_test "Examples/Tests/CaseTest.Mod" "20
99
2
2
2
2
100
300"

# --- RealTest ---
run_test "Examples/Tests/RealTest.Mod" "7
7
7
30
5
3
7
3
100
10
1
1
1
1
3
5
3
1
1000000
0"

# --- TypeTest ---
run_test "Examples/Tests/TypeTest.Mod" "100
-1
250
1
1000000
-42
999000
1
42
777
1"

echo ""
echo "========================================"
printf "  Results: %d passed, %d failed out of %d total\n" $PASS $FAIL $((PASS + FAIL))
echo "========================================"
if [ $FAIL -gt 0 ]; then
    echo -e "  Failed tests:$ERRORS"
    echo ""
fi
