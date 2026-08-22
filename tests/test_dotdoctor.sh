#!/bin/sh

set -u

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <dotdoctor-binary>" >&2
    exit 2
fi

DOTDOCTOR=$1
TMP_ROOT=$(mktemp -d)

trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

passed=0
failed=0

pass()
{
    printf 'PASS: %s\n' "$1"
    passed=$((passed + 1))
}

fail()
{
    printf 'FAIL: %s\n' "$1"
    failed=$((failed + 1))
}

expect_result()
{
    name=$1
    expected_rc=$2
    expected_stdout=$3
    shift 3

    stdout_file="$TMP_ROOT/stdout"
    stderr_file="$TMP_ROOT/stderr"

    "$@" >"$stdout_file" 2>"$stderr_file"
    actual_rc=$?
    actual_stdout=$(cat "$stdout_file")

    if [ "$actual_rc" -ne "$expected_rc" ]; then
        fail "$name"
        printf '  expected exit: %s\n' "$expected_rc"
        printf '  actual exit:   %s\n' "$actual_rc"
        cat "$stdout_file"
        cat "$stderr_file" >&2
        return
    fi

    if [ "$actual_stdout" != "$expected_stdout" ]; then
        fail "$name"
        printf '  expected stdout:\n%s\n' "$expected_stdout"
        printf '  actual stdout:\n%s\n' "$actual_stdout"
        cat "$stderr_file" >&2
        return
    fi

    pass "$name"
}

expect_exit()
{
    name=$1
    expected_rc=$2
    shift 2

    stdout_file="$TMP_ROOT/stdout"
    stderr_file="$TMP_ROOT/stderr"

    "$@" >"$stdout_file" 2>"$stderr_file"
    actual_rc=$?

    if [ "$actual_rc" -ne "$expected_rc" ]; then
        fail "$name"
        printf '  expected exit: %s\n' "$expected_rc"
        printf '  actual exit:   %s\n' "$actual_rc"
        cat "$stdout_file"
        cat "$stderr_file" >&2
        return
    fi

    pass "$name"
}

# 1. Empty directory

root="$TMP_ROOT/empty"
mkdir -p "$root"

expect_result \
    "empty directory" \
    0 \
    'OK: no broken symlinks found.' \
    "$DOTDOCTOR" "$root"

# 2. Regular file only

root="$TMP_ROOT/regular"
mkdir -p "$root"
touch "$root/file"

expect_result \
    "regular file only" \
    0 \
    'OK: no broken symlinks found.' \
    "$DOTDOCTOR" "$root"

# 3. Valid relative symlink

root="$TMP_ROOT/valid-relative"
mkdir -p "$root"
touch "$root/real-file"
ln -s real-file "$root/valid-link"

expect_result \
    "valid relative symlink" \
    0 \
    'OK: no broken symlinks found.' \
    "$DOTDOCTOR" "$root"

# 4. Broken relative symlink

root="$TMP_ROOT/broken-relative"
mkdir -p "$root"
ln -s missing-file "$root/broken-link"

expect_result \
    "broken relative symlink" \
    1 \
    'BROKEN: "broken-link" -> "missing-file"' \
    "$DOTDOCTOR" "$root"

# 5. Valid absolute symlink

root="$TMP_ROOT/valid-absolute"
mkdir -p "$root"
target="$TMP_ROOT/absolute-real-file"
touch "$target"
ln -s "$target" "$root/valid-link"

expect_result \
    "valid absolute symlink" \
    0 \
    'OK: no broken symlinks found.' \
    "$DOTDOCTOR" "$root"

# 6. Broken absolute symlink

root="$TMP_ROOT/broken-absolute"
mkdir -p "$root"
target="$TMP_ROOT/absolute-missing-file"
ln -s "$target" "$root/broken-link"

expect_result \
    "broken absolute symlink" \
    1 \
    "BROKEN: \"broken-link\" -> \"$target\"" \
    "$DOTDOCTOR" "$root"

# 7. Directory symlink must not be followed

root="$TMP_ROOT/directory-link-root"
target_dir="$TMP_ROOT/directory-link-target"

mkdir -p "$root" "$target_dir"
ln -s missing-child "$target_dir/broken-child"
ln -s "$target_dir" "$root/directory-link"

expect_result \
    "directory symlink is not followed" \
    0 \
    'OK: no broken symlinks found.' \
    "$DOTDOCTOR" "$root"

# 8. Nonexistent scan root

expect_exit \
    "nonexistent scan root" \
    2 \
    "$DOTDOCTOR" "$TMP_ROOT/does-not-exist"

# 9. Non-directory scan root

root="$TMP_ROOT/not-directory"
touch "$root"

expect_exit \
    "non-directory scan root" \
    2 \
    "$DOTDOCTOR" "$root"

# 10. Too many positional arguments

expect_exit \
    "too many positional arguments" \
    2 \
    "$DOTDOCTOR" one two

# 11. Multiple findings must be sorted

root="$TMP_ROOT/multiple"
mkdir -p "$root"

ln -s missing-z "$root/z-broken"
ln -s missing-a "$root/a-broken"

expected=$(printf '%s\n%s' \
    'BROKEN: "a-broken" -> "missing-a"' \
    'BROKEN: "z-broken" -> "missing-z"')

expect_result \
    "multiple findings are sorted" \
    1 \
    "$expected" \
    "$DOTDOCTOR" "$root"

# 12. Default $HOME/dotfiles

home="$TMP_ROOT/home"
mkdir -p "$home/dotfiles"
ln -s missing-default "$home/dotfiles/default-broken"

expect_result \
    "default HOME/dotfiles" \
    1 \
    'BROKEN: "default-broken" -> "missing-default"' \
    env HOME="$home" "$DOTDOCTOR"

printf '\n%d passed, %d failed\n' "$passed" "$failed"

if [ "$failed" -ne 0 ]; then
    exit 1
fi

exit 0
