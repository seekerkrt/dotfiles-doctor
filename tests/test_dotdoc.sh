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

# 18. Help lists exclude option

expect_stdout_contains \
    "--help lists exclude option" \
    '--exclude PATH' \
    "$DOTDOC" --help

# 19. Help documents exit status

expect_stdout_contains \
    "--help documents exit status" \
    'Exit status:' \
    "$DOTDOC" --help

# 20. Help explains exit status 1

expect_stdout_contains \
    "--help explains exit status 1" \
    'Exit status 1 indicates diagnostic findings, not program failure.' \
    "$DOTDOC" --help

# 21. Version

expect_result \
    "--version" \
    0 \
    "dotdoc $DOTDOC_VERSION" \
    "$DOTDOC" --version

# 22. Help must not depend on HOME

expect_stdout_contains \
    "--help works without HOME" \
    'Usage: dotdoc [OPTIONS] [PATH]' \
    env -u HOME "$DOTDOC" --help

# 23. Version must not depend on HOME

expect_result \
    "--version works without HOME" \
    0 \
    "dotdoc $DOTDOC_VERSION" \
    env -u HOME "$DOTDOC" --version

# 24. Self-referential symlink loop

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

# 25. Mutual symlink loop

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

# 26. Single finding summary

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

# 27. Multiple findings summary

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

# 28. Exclude one symlink

root="$TMP_ROOT/exclude"
mkdir -p "$root/cache"

target="$TMP_ROOT/exclude-missing"
ln -s "$target" "$root/keep-broken"
ln -s "$target" "$root/cache/hidden-broken"

expected=$(printf '%s\n%s\n%s' \
    "BROKEN: \"cache/hidden-broken\" -> \"$target\"" \
    "ABSOLUTE: \"cache/hidden-broken\" -> \"$target\"" \
    'Found 2 findings.')

expect_result \
    "exclude one symlink" \
    1 \
    "$expected" \
    "$DOTDOC" --exclude keep-broken "$root"

# 29. Exclude directory subtree

expected=$(printf '%s\n%s\n%s' \
    "BROKEN: \"keep-broken\" -> \"$target\"" \
    "ABSOLUTE: \"keep-broken\" -> \"$target\"" \
    'Found 2 findings.')

expect_result \
    "exclude directory subtree" \
    1 \
    "$expected" \
    "$DOTDOC" --exclude cache "$root"

# 30. Repeatable exclude

expect_result \
    "repeatable exclude" \
    0 \
    'OK: no findings.' \
    "$DOTDOC" --exclude cache --exclude keep-broken "$root"

# 31. Absolute exclude is rejected

expect_exit \
    "absolute exclude is rejected" \
    2 \
    "$DOTDOC" --exclude /etc "$root"

# 32. Exclude path escaping scan root is rejected

expect_exit \
    "exclude path escaping scan root is rejected" \
    2 \
    "$DOTDOC" --exclude ../secret "$root"

# 33. Normalized exclude path escaping scan root is rejected

expect_exit \
    "normalized exclude path escaping scan root is rejected" \
    2 \
    "$DOTDOC" --exclude cache/../../secret "$root"

# 34. Safe normalized exclude path

expect_result \
    "safe normalized exclude path" \
    1 \
    "$expected" \
    "$DOTDOC" --exclude cache/../cache "$root"

# 35. Exclude entire scan root

expect_result \
    "exclude entire scan root" \
    0 \
    'OK: no findings.' \
    "$DOTDOC" --exclude . "$root"

# 36. Exclude requires path argument

expect_exit \
    "exclude requires path argument" \
    2 \
    "$DOTDOC" --exclude

# 37. Nonexistent exclude is a no-op

expected=$(printf '%s\n%s\n%s\n%s\n%s' \
    "BROKEN: \"cache/hidden-broken\" -> \"$target\"" \
    "ABSOLUTE: \"cache/hidden-broken\" -> \"$target\"" \
    "BROKEN: \"keep-broken\" -> \"$target\"" \
    "ABSOLUTE: \"keep-broken\" -> \"$target\"" \
    'Found 4 findings.')

expect_result \
    "nonexistent exclude is a no-op" \
    1 \
    "$expected" \
    "$DOTDOC" --exclude nonexistent "$root"

# 38. Empty exclude is rejected

expect_exit \
    "empty exclude is rejected" \
    2 \
    "$DOTDOC" --exclude "" "$root"

# 39. Exclude works with relative scan root

relative_parent="$TMP_ROOT/relative-parent"
root="$relative_parent/tree"
mkdir -p "$root/cache"

target="$TMP_ROOT/relative-missing"
ln -s "$target" "$root/keep-broken"
ln -s "$target" "$root/cache/hidden-broken"

dotdoc_dir=$(dirname "$DOTDOC")
dotdoc_base=$(basename "$DOTDOC")
dotdoc_absolute=$(cd "$dotdoc_dir" && pwd)/$dotdoc_base

expected=$(printf '%s\n%s\n%s' \
    "BROKEN: \"keep-broken\" -> \"$target\"" \
    "ABSOLUTE: \"keep-broken\" -> \"$target\"" \
    'Found 2 findings.')

expect_result \
    "exclude works with relative scan root" \
    1 \
    "$expected" \
    sh -c 'cd "$1" && exec "$2" --exclude cache tree' \
    sh "$relative_parent" "$dotdoc_absolute"

# 39. Exclude option works after positional scan root

expected=$(printf '%s\n%s\n%s' \
    "BROKEN: \"keep-broken\" -> \"$target\"" \
    "ABSOLUTE: \"keep-broken\" -> \"$target\"" \
    'Found 2 findings.')

expect_result \
    "exclude option works after positional scan root" \
    1 \
    "$expected" \
    "$DOTDOC" "$root" --exclude cache

# 40. Path normalized to current directory excludes entire scan root

expect_result \
    "normalized current-directory exclude excludes entire scan root" \
    0 \
    'OK: no findings.' \
    "$DOTDOC" --exclude foo/.. "$root"

# 41. Exclude works with relative scan root

relative_parent="$TMP_ROOT/relative-parent"
root="$relative_parent/tree"
mkdir -p "$root/cache"

target="$TMP_ROOT/relative-missing"
ln -s "$target" "$root/keep-broken"
ln -s "$target" "$root/cache/hidden-broken"

dotdoc_dir=$(dirname "$DOTDOC")
dotdoc_base=$(basename "$DOTDOC")
dotdoc_absolute=$(cd "$dotdoc_dir" && pwd)/$dotdoc_base

expected=$(printf '%s\n%s\n%s' \
    "BROKEN: \"keep-broken\" -> \"$target\"" \
    "ABSOLUTE: \"keep-broken\" -> \"$target\"" \
    'Found 2 findings.')

expect_result \
    "exclude works with relative scan root" \
    1 \
    "$expected" \
    sh -c 'cd "$1" && exec "$2" --exclude cache tree' \
    sh "$relative_parent" "$dotdoc_absolute"

# 42. Max depth zero scans no entries

root="$TMP_ROOT/max-depth"
mkdir -p "$root/dir/sub"

ln -s missing-depth1 "$root/depth1"
ln -s missing-depth2 "$root/dir/depth2"
ln -s missing-depth3 "$root/dir/sub/depth3"

expect_result \
    "max depth zero scans no entries" \
    0 \
    'OK: no findings.' \
    "$DOTDOC" --max-depth 0 "$root"

# 43. Max depth one scans direct entries only

expected=$(printf '%s\n%s' \
    'BROKEN: "depth1" -> "missing-depth1"' \
    'Found 1 finding.')

expect_result \
    "max depth one scans direct entries only" \
    1 \
    "$expected" \
    "$DOTDOC" --max-depth 1 "$root"

# 44. Max depth two scans through depth two

expected=$(printf '%s\n%s\n%s' \
    'BROKEN: "depth1" -> "missing-depth1"' \
    'BROKEN: "dir/depth2" -> "missing-depth2"' \
    'Found 2 findings.')

expect_result \
    "max depth two scans through depth two" \
    1 \
    "$expected" \
    "$DOTDOC" --max-depth 2 "$root"

# 45. Max depth works with exclude

expected=$(printf '%s\n%s' \
    'BROKEN: "depth1" -> "missing-depth1"' \
    'Found 1 finding.')

expect_result \
    "max depth works with exclude" \
    1 \
    "$expected" \
    "$DOTDOC" --max-depth 3 --exclude dir "$root"

# 46. Max depth requires integer argument

expect_exit \
    "max depth requires integer argument" \
    2 \
    "$DOTDOC" --max-depth

# 47. Negative max depth is rejected

expect_exit \
    "negative max depth is rejected" \
    2 \
    "$DOTDOC" --max-depth -1 "$root"

# 48. Non-numeric max depth is rejected

expect_exit \
    "non-numeric max depth is rejected" \
    2 \
    "$DOTDOC" --max-depth foo "$root"

# 49. Max depth with trailing garbage is rejected

expect_exit \
    "max depth with trailing garbage is rejected" \
    2 \
    "$DOTDOC" --max-depth 1x "$root"

# 50. Max depth overflow is rejected

expect_exit \
    "max depth overflow is rejected" \
    2 \
    "$DOTDOC" --max-depth 999999999999999999999999999999999999 "$root"

# 51. Repeated max depth uses the last value

expected=$(printf '%s\n%s\n%s' \
    'BROKEN: "depth1" -> "missing-depth1"' \
    'BROKEN: "dir/depth2" -> "missing-depth2"' \
    'Found 2 findings.')

expect_result \
    "repeated max depth uses the last value" \
    1 \
    "$expected" \
    "$DOTDOC" --max-depth 1 --max-depth 2 "$root"

# 52. Max depth works after positional scan root

expect_result \
    "max depth works after positional scan root" \
    1 \
    "$expected" \
    "$DOTDOC" "$root" --max-depth 2

# 53. Max depth does not follow directory symlinks

root="$TMP_ROOT/max-depth-directory-link"
target_dir="$TMP_ROOT/max-depth-directory-link-target"

mkdir -p "$root" "$target_dir/sub"
ln -s missing-child "$target_dir/sub/broken-child"
ln -s "$target_dir" "$root/directory-link"

expected=$(printf '%s\n%s' \
    "ABSOLUTE: \"directory-link\" -> \"$target_dir\"" \
    'Found 1 finding.')

expect_result \
    "max depth does not follow directory symlinks" \
    1 \
    "$expected" \
    "$DOTDOC" --max-depth 3 "$root"

printf '\n%d passed, %d failed\n' "$passed" "$failed"

if [ "$failed" -ne 0 ]; then
    exit 1
fi

exit 0
