#!/bin/sh

set -u

if [ "$#" -ne 2 ]; then
    echo "usage: $0 <dotdoc-binary> <version>" >&2
    exit 2
fi

DOTDOC=$1
DOTDOC_VERSION=$2
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

expect_stdout_contains()
{
    name=$1
    expected_text=$2
    shift 2

    stdout_file="$TMP_ROOT/stdout"
    stderr_file="$TMP_ROOT/stderr"

    "$@" >"$stdout_file" 2>"$stderr_file"
    actual_rc=$?

    if [ "$actual_rc" -ne 0 ]; then
        fail "$name"
        printf '  expected exit: 0\n'
        printf '  actual exit:   %s\n' "$actual_rc"
        cat "$stdout_file"
        cat "$stderr_file" >&2
        return
    fi

    if ! grep -Fq -- "$expected_text" "$stdout_file"; then
        fail "$name"
        printf '  expected stdout to contain:\n%s\n' "$expected_text"
        printf '  actual stdout:\n'
        cat "$stdout_file"
        return
    fi

    if [ -s "$stderr_file" ]; then
        fail "$name"
        printf '  expected stderr to be empty\n'
        printf '  actual stderr:\n' >&2
        cat "$stderr_file" >&2
        return
    fi

    pass "$name"
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

    if [ -s "$stderr_file" ]; then
        fail "$name"
        printf '  expected stderr to be empty\n'
        printf '  actual stderr:\n' >&2
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

    if [ -s "$stdout_file" ]; then
        fail "$name"
        printf '  expected stdout to be empty\n'
        printf '  actual stdout:\n'
        cat "$stdout_file"
        return
    fi

    if [ ! -s "$stderr_file" ]; then
        fail "$name"
        printf '  expected stderr output\n'
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
    'OK: no findings.' \
    "$DOTDOC" "$root"

# 2. Regular file only

root="$TMP_ROOT/regular"
mkdir -p "$root"
touch "$root/file"

expect_result \
    "regular file only" \
    0 \
    'OK: no findings.' \
    "$DOTDOC" "$root"

# 3. Valid relative symlink

root="$TMP_ROOT/valid-relative"
mkdir -p "$root"
touch "$root/real-file"
ln -s real-file "$root/valid-link"

expect_result \
    "valid relative symlink" \
    0 \
    'OK: no findings.' \
    "$DOTDOC" "$root"

# 4. Broken relative symlink

root="$TMP_ROOT/broken-relative"
mkdir -p "$root"
ln -s missing-file "$root/broken-link"

expected=$(printf '%s\n%s' \
    'BROKEN: "broken-link" -> "missing-file"' \
    'Found 1 finding.')

expect_result \
    "broken relative symlink" \
    1 \
    "$expected" \
    "$DOTDOC" "$root"

# 5. Valid absolute symlink

root="$TMP_ROOT/valid-absolute"
mkdir -p "$root"
target="$TMP_ROOT/absolute-real-file"
touch "$target"
ln -s "$target" "$root/valid-link"

expected=$(printf '%s\n%s' \
    "ABSOLUTE: \"valid-link\" -> \"$target\"" \
    'Found 1 finding.')

expect_result \
    "valid absolute symlink" \
    1 \
    "$expected" \
    "$DOTDOC" "$root"

# 6. Broken absolute symlink

root="$TMP_ROOT/broken-absolute"
mkdir -p "$root"
target="$TMP_ROOT/absolute-missing-file"
ln -s "$target" "$root/broken-link"

expected=$(printf '%s\n%s\n%s' \
    "BROKEN: \"broken-link\" -> \"$target\"" \
    "ABSOLUTE: \"broken-link\" -> \"$target\"" \
    'Found 2 findings.')

expect_result \
    "broken absolute symlink" \
    1 \
    "$expected" \
    "$DOTDOC" "$root"

# 7. Directory symlink must not be followed

root="$TMP_ROOT/directory-link-root"
target_dir="$TMP_ROOT/directory-link-target"

mkdir -p "$root" "$target_dir"
ln -s missing-child "$target_dir/broken-child"
ln -s "$target_dir" "$root/directory-link"

expected=$(printf '%s\n%s' \
    "ABSOLUTE: \"directory-link\" -> \"$target_dir\"" \
    'Found 1 finding.')

expect_result \
    "directory symlink is not followed" \
    1 \
    "$expected" \
    "$DOTDOC" "$root"

# 8. Nonexistent scan root

expect_exit \
    "nonexistent scan root" \
    2 \
    "$DOTDOC" "$TMP_ROOT/does-not-exist"

# 9. Non-directory scan root

root="$TMP_ROOT/not-directory"
touch "$root"

expect_exit \
    "non-directory scan root" \
    2 \
    "$DOTDOC" "$root"

# 10. Too many positional arguments

expect_exit \
    "too many positional arguments" \
    2 \
    "$DOTDOC" one two

# 11. Multiple findings must be sorted

root="$TMP_ROOT/multiple"
mkdir -p "$root"

target="$TMP_ROOT/absolute-target"
touch "$target"

ln -s missing-z "$root/z-broken"
ln -s "$target" "$root/a-absolute"

expected=$(printf '%s\n%s\n%s' \
    "ABSOLUTE: \"a-absolute\" -> \"$target\"" \
    'BROKEN: "z-broken" -> "missing-z"' \
    'Found 2 findings.')

expect_result \
    "multiple findings are sorted" \
    1 \
    "$expected" \
    "$DOTDOC" "$root"

# 12. Default $HOME/dotfiles

home="$TMP_ROOT/home"
mkdir -p "$home/dotfiles"
ln -s missing-default "$home/dotfiles/default-broken"

expected=$(printf '%s\n%s' \
    'BROKEN: "default-broken" -> "missing-default"' \
    'Found 1 finding.')

expect_result \
    "default HOME/dotfiles" \
    1 \
    "$expected" \
    env HOME="$home" "$DOTDOC"

# 13. HOME unset

expect_exit \
    "HOME unset" \
    2 \
    env -u HOME "$DOTDOC"

# 14. HOME empty

expect_exit \
    "HOME empty" \
    2 \
    env HOME= "$DOTDOC"

# 15. Short help option

expect_stdout_contains \
    "-h shows help" \
    'Usage: dotdoc [OPTIONS] [PATH]' \
    "$DOTDOC" -h

# 16. Long help option

expect_stdout_contains \
    "--help shows default path" \
    'Without PATH, $HOME/dotfiles is scanned.' \
    "$DOTDOC" --help

# 17. Help lists version option

expect_stdout_contains \
    "--help lists version option" \
    '--version' \
    "$DOTDOC" --help

# 18. Help documents exit status

expect_stdout_contains \
    "--help documents exit status" \
    'Exit status:' \
    "$DOTDOC" --help

# 19. Help explains exit status 1

expect_stdout_contains \
    "--help explains exit status 1" \
    'Exit status 1 indicates diagnostic findings, not program failure.' \
    "$DOTDOC" --help

# 20. Version

expect_result \
    "--version" \
    0 \
    "dotdoc $DOTDOC_VERSION" \
    "$DOTDOC" --version

# 21. Help must not depend on HOME

expect_stdout_contains \
    "--help works without HOME" \
    'Usage: dotdoc [OPTIONS] [PATH]' \
    env -u HOME "$DOTDOC" --help

# 22. Version must not depend on HOME

expect_result \
    "--version works without HOME" \
    0 \
    "dotdoc $DOTDOC_VERSION" \
    env -u HOME "$DOTDOC" --version

# 23. Self-referential symlink loop

root="$TMP_ROOT/loop-self"
mkdir -p "$root"
ln -s self-link "$root/self-link"

expected=$(printf '%s\n%s' \
    'BROKEN: "self-link" -> "self-link"' \
    'Found 1 finding.')

expect_result \
    "self-referential symlink loop" \
    1 \
    "$expected" \
    "$DOTDOC" "$root"

# 24. Mutual symlink loop

root="$TMP_ROOT/loop-mutual"
mkdir -p "$root"
ln -s b-link "$root/a-link"
ln -s a-link "$root/b-link"

expected=$(printf '%s\n%s\n%s' \
    'BROKEN: "a-link" -> "b-link"' \
    'BROKEN: "b-link" -> "a-link"' \
    'Found 2 findings.')

expect_result \
    "mutual symlink loop" \
    1 \
    "$expected" \
    "$DOTDOC" "$root"

# 25. Single finding summary

root="$TMP_ROOT/summary-single"
mkdir -p "$root"
ln -s missing "$root/broken"

expected=$(printf '%s\n%s' \
    'BROKEN: "broken" -> "missing"' \
    'Found 1 finding.')

expect_result \
    "single finding summary" \
    1 \
    "$expected" \
    "$DOTDOC" "$root"

# 26. Multiple findings summary

root="$TMP_ROOT/summary-multiple"
mkdir -p "$root"
ln -s missing-b "$root/b"
ln -s missing-a "$root/a"

expected=$(printf '%s\n%s\n%s' \
    'BROKEN: "a" -> "missing-a"' \
    'BROKEN: "b" -> "missing-b"' \
    'Found 2 findings.')

expect_result \
    "multiple findings summary" \
    1 \
    "$expected" \
    "$DOTDOC" "$root"

printf '\n%d passed, %d failed\n' "$passed" "$failed"

if [ "$failed" -ne 0 ]; then
    exit 1
fi

exit 0
