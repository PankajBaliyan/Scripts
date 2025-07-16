#!/usr/bin/env bash

SCRIPT_TO_TEST="./pipenv_temp_env.sh"

PASSED=0
FAILED=0
TOTAL=0

# === UTILS ===

run_test() {
    local test_desc="$1"
    local PATH_OVERRIDE="$2"
    echo "=== Test: $test_desc ==="
    OUTPUT=$(PATH="$PATH_OVERRIDE:$PATH" bash "$SCRIPT_TO_TEST" 2>&1)
    EXIT_CODE=$?
    echo "$OUTPUT"
    echo "Exit code: $EXIT_CODE"
    echo
    TOTAL=$((TOTAL + 1))
    return $EXIT_CODE
}

prepare_fake_commands() {
    local tmpdir="$1"
    shift
    for cmd in "$@"; do
        echo -e "#!/usr/bin/env bash\necho \"$cmd dummy version\"" >"$tmpdir/$cmd"
        chmod +x "$tmpdir/$cmd"
    done
}

check_result() {
    local expected_exit="$1"
    shift
    local expected_msgs=("$@")

    # Check exit code
    if [[ $EXIT_CODE -ne $expected_exit ]]; then
        echo "FAIL: Expected exit code $expected_exit but got $EXIT_CODE"
        FAILED=$((FAILED + 1))
        return
    fi

    # Check all expected messages appear in output
    for msg in "${expected_msgs[@]}"; do
        if ! echo "$OUTPUT" | grep -qF "$msg"; then
            echo "FAIL: Expected message not found: $msg"
            FAILED=$((FAILED + 1))
            return
        fi
    done

    echo "PASS"
    PASSED=$((PASSED + 1))
}

# === TESTS ===

test_all_present() {
    tmpdir=$(mktemp -d)
    prepare_fake_commands "$tmpdir" pipenv jupyter python3
    run_test "All commands present" "$tmpdir"
    check_result 0 "All required dependencies are installed"
    rm -rf "$tmpdir"
}

test_missing_pipenv() {
    tmpdir=$(mktemp -d)
    prepare_fake_commands "$tmpdir" jupyter python3
    run_test "Missing pipenv" "$tmpdir"
    check_result 1 "pipenv is not installed" "One or more dependencies are missing"
    rm -rf "$tmpdir"
}

test_missing_jupyter() {
    tmpdir=$(mktemp -d)
    prepare_fake_commands "$tmpdir" pipenv python3
    run_test "Missing jupyter" "$tmpdir"
    check_result 1 "jupyter is not installed" "One or more dependencies are missing"
    rm -rf "$tmpdir"
}

test_missing_python3() {
    tmpdir=$(mktemp -d)
    prepare_fake_commands "$tmpdir" pipenv jupyter
    run_test "Missing python3" "$tmpdir"
    check_result 1 "python3 is not installed" "One or more dependencies are missing"
    rm -rf "$tmpdir"
}

test_missing_all() {
    run_test "Missing all commands" "/nonexistent_path"
    check_result 1 "pipenv is not installed" "jupyter is not installed" "python3 is not installed" "One or more dependencies are missing"
}

# Run all tests
test_all_present
test_missing_pipenv
test_missing_jupyter
test_missing_python3
test_missing_all

# Summary
echo "=== Test summary ==="
echo "Total tests: $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
