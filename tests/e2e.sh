#!/usr/bin/env bash
# End-to-end tests: run the built binary and compare its standard output
# (byte for byte), and where given its standard error, and exit status with
# the expected ones. The cases run inside a fixture tree built under $TMP.
#
# usage: tests/e2e.sh BINARY

set -u
BIN=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
pass=0
fail=0

# check_file NAME STATUS EXPECTED_FILE [ARGS...]
# Runs BINARY ARGS... with standard input from the file named by $IN
# (default: /dev/null) and compares standard output with EXPECTED_FILE.
# If $WANT_ERR is set, standard error must equal it too.
check_file() {
    local name=$1 want_status=$2 want_file=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    local err_ok=1
    if [ -n "${WANT_ERR+set}" ]; then
        printf '%s' "$WANT_ERR" > "$TMP/want_err"
        cmp -s "$TMP/want_err" "$TMP/err" || err_ok=0
    fi
    if [ "$status" -eq "$want_status" ] && cmp -s "$want_file" "$TMP/out" && [ "$err_ok" -eq 1 ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(od -c "$want_file") <(od -c "$TMP/out") | sed 's/^/    /' | head -20
        if [ "$err_ok" -eq 0 ]; then
            diff <(od -c "$TMP/want_err") <(od -c "$TMP/err") | sed 's/^/    stderr /' | head -20
        fi
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# check NAME STATUS EXPECTED_STDOUT [ARGS...]
# As check_file, with the expected output given as a string. Bash strings
# cannot hold NUL bytes; use check_file for output that contains them.
check() {
    local name=$1 want_status=$2
    printf '%s' "$3" > "$TMP/want"
    shift 3
    check_file "$name" "$want_status" "$TMP/want" "$@"
}

# check_both NAME STATUS EXPECTED_STDOUT EXPECTED_STDERR [ARGS...]
check_both() {
    local name=$1 want_status=$2 want_out=$3
    local WANT_ERR=$4
    shift 4
    check "$name" "$want_status" "$want_out" "$@"
}

# check_tree NAME DIR EXPECTED: the files and directories under DIR (sorted,
# one per line, relative) must equal EXPECTED.
check_tree() {
    local name=$1 dir=$2 want=$3
    local got
    got=$(cd "$dir" 2>/dev/null && find . -mindepth 1 | sed 's|^\./||' | LC_ALL=C sort)
    if [ "$got" = "$want" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (tree of $dir)"
        diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /' | head -20
    fi
}

# check_norm NAME STATUS EXPECTED [ARGS...]: like check, after replacing in
# standard output the fixture directory (as robocopy prints it, with `\`) by
# <W>, the start and end times by <time>, the Times row by <times> and the
# time stamps of error lines by <stamp>.
check_norm() {
    local name=$1 want_status=$2 want=$3
    shift 3
    "$BIN" "$@" < "${IN:-/dev/null}" > "$TMP/out" 2> "$TMP/err"
    local status=$?
    local got
    got=$(sed -E 's/^(  Started : |   Ended : ).*/\1<time>/; s/^   Times :.*/   Times : <times>/; s/^[0-9]{4}\/[0-9]{2}\/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} ERROR/<stamp> ERROR/' "$TMP/out"; echo x)
    got=${got%x}
    got=${got//"$WB"/<W>}
    if [ "$status" -eq "$want_status" ] && [ "$got" = "$want" ]; then
        pass=$((pass + 1))
    else
        fail=$((fail + 1))
        echo "FAIL: $name (exit $status, expected $want_status)"
        diff <(printf '%s' "$want") <(printf '%s' "$got") | sed 's/^/    /' | head -30
        sed 's/^/    stderr: /' "$TMP/err" | head -5
    fi
}

# The fixture trees, under $TMP only. W is the physical path, as `pwd`
# gives it; WB the same with `\`, as robocopy prints it.
mkdir -p "$TMP/w"
W=$(cd "$TMP/w" && pwd -P)
WB=$(printf '%s' "$W" | tr '/' '\\')
mkdir -p "$W/src/sub/deep" "$W/src/empty" "$W/src/obj" "$W/outside"
printf 'alpha\n' > "$W/src/a.txt"
printf 'bravo\n' > "$W/src/b.log"
printf 'temp\n' > "$W/src/c.tmp"
printf 'charlie\n' > "$W/src/sub/c.txt"
printf 'delta\n' > "$W/src/sub/deep/d.txt"
printf 'object\n' > "$W/src/obj/o.txt"
printf 'keep me\n' > "$W/outside/precious.txt"
cd "$W"

# Expected texts are written with <TAB> for a tab; t reads one from
# standard input (the final line end is added back by the callers).
t() {
    local s
    s=$(cat)
    printf '%s' "${s//<TAB>/$'\t'}"
}

# Help, version and fatal parameter errors (exit 16).
help=$(printf '%s\n' \
'Copies and mirrors directory trees.' \
'' \
'ROBOCOPY source destination [file [file]...] [options]' \
'' \
'  file      Names or wildcards of the files to copy (default *.*).' \
'  /S        Copy subdirectories, except empty ones.' \
'  /E        Copy subdirectories, including empty ones.' \
'  /PURGE    Delete destination files and directories that are not in the source.' \
'  /MIR      Mirror a tree (/E plus /PURGE).' \
'  /MOV      Move files (delete them from the source once copied).' \
'  /MOVE     Move files and directories.' \
'  /XF f...  Exclude files matching these names or wildcards.' \
'  /XD d...  Exclude directories matching these names or paths.' \
'  /L        List only: change nothing.' \
'  /NP       No progress percentage.' \
'  /NFL      No file list.' \
'  /NDL      No directory list.' \
'  /NJH      No job header.' \
'  /NJS      No job summary.' \
'' \
'Exit status: a bit mask: 1 files copied, 2 extra entries, 4 mismatches,' \
'8 failures; 16 a fatal error.')$'\n'
check_both "/? help"                 0 "$help" ''               '/?'
check      "--version"               0 $'robocopy (loup-cmd-robocopy) 0.1.0\n' --version
check_both "no arguments"            16 "$help" ''
check_both "no destination"          16 '' $'ERROR : No Destination Directory Specified.\n' src
check_both "invalid parameter"       16 '' $'ERROR : Invalid Parameter #3 : "/ZZ"\n' src dst /ZZ
check_both "empty /XF"               16 '' $'ERROR : Invalid Parameter #4 : "/XF"\n' src dst /S /XF

# A first copy: the job header, every directory and file, the summary.
want=$(t <<'END'

-------------------------------------------------------------------------------
   ROBOCOPY     ::     Robust File Copy (loup-cmd-robocopy)
-------------------------------------------------------------------------------

  Started : <time>
   Source : <W>\src\
     Dest : <W>\dst\

    Files : *.*

  Options : *.* /S /E

------------------------------------------------------------------------------

<TAB>  New Dir          3<TAB><W>\src\
<TAB>    New File  <TAB><TAB>       6<TAB>a.txt
100%
<TAB>    New File  <TAB><TAB>       6<TAB>b.log
100%
<TAB>    New File  <TAB><TAB>       5<TAB>c.tmp
100%
<TAB>  New Dir          0<TAB><W>\src\empty\
<TAB>  New Dir          1<TAB><W>\src\obj\
<TAB>    New File  <TAB><TAB>       7<TAB>o.txt
100%
<TAB>  New Dir          1<TAB><W>\src\sub\
<TAB>    New File  <TAB><TAB>       8<TAB>c.txt
100%
<TAB>  New Dir          1<TAB><W>\src\sub\deep\
<TAB>    New File  <TAB><TAB>       6<TAB>d.txt
100%

------------------------------------------------------------------------------

               Total    Copied   Skipped  Mismatch    FAILED    Extras
    Dirs :         5         5         0         0         0         0
   Files :         6         6         0         0         0         0
   Bytes :        38        38         0         0         0         0
   Times : <times>
   Ended : <time>
END
)$'\n\n'
check_norm "first copy /E"           1 "$want"                  src dst /E
check_tree "first copy tree"         dst $'a.txt\nb.log\nc.tmp\nempty\nobj\nobj/o.txt\nsub\nsub/c.txt\nsub/deep\nsub/deep/d.txt'
cmp -s src/sub/deep/d.txt dst/sub/deep/d.txt && pass=$((pass + 1)) || { fail=$((fail + 1)); echo "FAIL: content"; }

summary_tail() {
    printf '%s\n' '' "------------------------------------------------------------------------------" '' \
        '               Total    Copied   Skipped  Mismatch    FAILED    Extras' "$@" \
        '   Times : <times>' '   Ended : <time>' ''
}
in_sync_dirs=$(t <<'END'
<TAB>                   3<TAB><W>\src\
<TAB>                   0<TAB><W>\src\empty\
<TAB>                   1<TAB><W>\src\obj\
<TAB>                   1<TAB><W>\src\sub\
<TAB>                   1<TAB><W>\src\sub\deep\
END
)$'\n'
check_norm "in sync"                 0 "$in_sync_dirs$(summary_tail \
    '    Dirs :         5         0         5         0         0         0' \
    '   Files :         6         0         6         0         0         0' \
    '   Bytes :        38         0        38         0         0         0')"$'\n\n' src dst /E /NJH

# A changed file and extras: a file, a directory, and directory symbolic
# links pointing outside the tree (which /MIR must unlink, not follow).
printf 'ALPHA\n' > src/a.txt
printf 'x\n' > dst/extra.txt
mkdir -p dst/old/inner
printf 'o\n' > dst/old/inner/o.txt
ln -s ../../outside dst/old/inner/link
ln -s ../outside dst/toplink
extras=$(t <<'END'
<TAB>                   3<TAB><W>\src\
<TAB>*EXTRA File   <TAB><TAB>       2<TAB>extra.txt
<TAB>*EXTRA Dir        -1<TAB><W>\dst\old\
<TAB>*EXTRA Dir        -1<TAB><W>\dst\toplink\
END
)$'\n'
rest_dirs=$(t <<'END'
<TAB>                   0<TAB><W>\src\empty\
<TAB>                   1<TAB><W>\src\obj\
<TAB>                   1<TAB><W>\src\sub\
<TAB>                   1<TAB><W>\src\sub\deep\
END
)$'\n'
check_norm "changed and extras"      3 "$extras"$'\t    Changed   \t\t       6\ta.txt\n'"$rest_dirs$(summary_tail \
    '    Dirs :         5         0         5         0         0         2' \
    '   Files :         6         1         5         0         0         1' \
    '   Bytes :        38         6        32         0         0         2')"$'\n\n' src dst /E /NJH /NP
check_norm "/MIR /L lists"           2 "$extras$rest_dirs"      src dst /MIR /L /NJH /NJS
check_tree "/L changed nothing"      dst $'a.txt\nb.log\nc.tmp\nempty\nextra.txt\nobj\nobj/o.txt\nold\nold/inner\nold/inner/link\nold/inner/o.txt\nsub\nsub/c.txt\nsub/deep\nsub/deep/d.txt\ntoplink'
check_norm "/MIR purges"             2 "$extras$rest_dirs$(summary_tail \
    '    Dirs :         5         0         5         0         0         2' \
    '   Files :         6         0         6         0         0         1' \
    '   Bytes :        38         0        38         0         0         2')"$'\n\n' src dst /MIR /NJH /NP
check_tree "/MIR tree"               dst $'a.txt\nb.log\nc.tmp\nempty\nobj\nobj/o.txt\nsub\nsub/c.txt\nsub/deep\nsub/deep/d.txt'
check_tree "link targets kept"       outside 'precious.txt'
check_norm "/NFL /NDL"               0 "$(summary_tail \
    '    Dirs :         5         0         5         0         0         0' \
    '   Files :         6         0         6         0         0         0' \
    '   Bytes :        38         0        38         0         0         0')"$'\n\n' src dst /MIR /NJH /NFL /NDL
check_norm "/NJH /NJS /NDL in sync"  0 ''                       src dst /MIR /NJH /NJS /NDL

# File patterns, /XF and /XD.
want=$(t <<'END'

-------------------------------------------------------------------------------
   ROBOCOPY     ::     Robust File Copy (loup-cmd-robocopy)
-------------------------------------------------------------------------------

  Started : <time>
   Source : <W>\src\
     Dest : <W>\pat\

    Files : *.txt
<TAB>    *.log
Exc Files : a*
 Exc Dirs : obj
<TAB>    deep

  Options : *.txt *.log /S /NJS

------------------------------------------------------------------------------

<TAB>  New Dir          1<TAB><W>\src\
<TAB>    New File  <TAB><TAB>       6<TAB>b.log
100%
<TAB>  New Dir          1<TAB><W>\src\sub\
<TAB>    New File  <TAB><TAB>       8<TAB>c.txt
100%
END
)$'\n'
check_norm "patterns /XF /XD"        1 "$want"                  src pat '*.txt' '*.log' /S /XF 'a*' /XD obj deep /NJS
check_tree "patterns tree"           pat $'b.log\nsub\nsub/c.txt'

# /MOVE: files and emptied directories leave the source (its root stays);
# excluded files stay behind.
mkdir -p mv/s
printf '1\n' > mv/one.txt
printf '2\n' > mv/s/two.txt
printf 't\n' > mv/s/x.tmp
want=$(t <<'END'
<TAB>  New Dir          1<TAB><W>\mv\
<TAB>    New File  <TAB><TAB>       2<TAB>one.txt
<TAB>  New Dir          1<TAB><W>\mv\s\
<TAB>    New File  <TAB><TAB>       2<TAB>two.txt
END
)$'\n'
check_norm "/MOVE"                   1 "$want"                  mv mvd /MOVE /S /XF '*.tmp' /NJH /NJS /NP
check_tree "/MOVE source"            mv $'s\ns/x.tmp'
check_tree "/MOVE destination"       mvd $'one.txt\ns\ns/two.txt'
mkdir -p mo
printf '1\n' > mo/one.txt
check_norm "/MOV keeps directories"  1 $'\t  New Dir          1\t<W>\\mo\\\n\t    New File  \t\t       2\tone.txt\n' mo mod /MOV /NJH /NJS /NP
check_tree "/MOV source"             mo ''

# Mismatches: a directory where a file belongs, a file where a directory
# belongs (exit 4, plus 1 for the files copied).
mkdir -p mm/a.txt
printf 'f\n' > mm/sub
want=$(t <<'END'
<TAB>                   3<TAB><W>\src\
<TAB>*MISMATCH     <TAB><TAB>       6<TAB>a.txt
<TAB>    New File  <TAB><TAB>       6<TAB>b.log
<TAB>    New File  <TAB><TAB>       5<TAB>c.tmp
<TAB>*MISMATCH          1<TAB><W>\src\sub\
END
)$'\n'
check_norm "mismatches"              5 "$want$(summary_tail \
    '    Dirs :         2         0         1         1         0         0' \
    '   Files :         3         2         0         1         0         0' \
    '   Bytes :        17        11         0         6         0         0')"$'\n\n' src mm /S /XD obj /NJH /NP

# A missing source: the header, the error, exit 16.
want=$(t <<'END'

-------------------------------------------------------------------------------
   ROBOCOPY     ::     Robust File Copy (loup-cmd-robocopy)
-------------------------------------------------------------------------------

  Started : <time>
   Source : <W>\nope\
     Dest : <W>\dst\

    Files : *.*

  Options : *.*

------------------------------------------------------------------------------

<stamp> ERROR 2 (0x00000002) Accessing Source Directory <W>\nope\
The system cannot find the file specified.
END
)$'\n'
check_norm "missing source"          16 "$want"                 nope dst

# The destination inside the source is not copied into itself.
check_norm "destination inside"      1 "$(t <<'END'
<TAB>  New Dir          3<TAB><W>\src\
<TAB>  New Dir          0<TAB><W>\src\empty\
<TAB>  New Dir          1<TAB><W>\src\obj\
<TAB>  New Dir          1<TAB><W>\src\sub\
<TAB>  New Dir          1<TAB><W>\src\sub\deep\
END
)"$'\n' src 'src\backup' /E /NJH /NJS /NFL
check_tree "inside tree"             src/backup $'a.txt\nb.log\nc.tmp\nempty\nobj\nobj/o.txt\nsub\nsub/c.txt\nsub/deep\nsub/deep/d.txt'
rm -rf src/backup

# A directory that cannot be written: ERROR lines, FAILED counts, exit 9.
# (Skipped as root, which ignores permissions.)
if [ "$(id -u)" -ne 0 ]; then
    mkdir -p ro/sub
    chmod 555 ro/sub
    want=$(t <<'END'
<TAB>                   3<TAB><W>\src\
<TAB>    New File  <TAB><TAB>       6<TAB>a.txt
<TAB>    New File  <TAB><TAB>       6<TAB>b.log
<TAB>    New File  <TAB><TAB>       5<TAB>c.tmp
<TAB>                   1<TAB><W>\src\sub\
<TAB>    New File  <TAB><TAB>       8<TAB>c.txt
<stamp> ERROR 5 (0x00000005) Copying File <W>\src\sub\c.txt
Access is denied.
<TAB>  New Dir          1<TAB><W>\src\sub\deep\
<stamp> ERROR 5 (0x00000005) Creating Destination Directory <W>\ro\sub\deep\
Access is denied.
<TAB>    New File  <TAB><TAB>       6<TAB>d.txt
<stamp> ERROR 5 (0x00000005) Copying File <W>\src\sub\deep\d.txt
Access is denied.
END
)$'\n'
    check_norm "write failures"      9 "$want$(summary_tail \
        '    Dirs :         3         0         2         0         1         0' \
        '   Files :         5         3         0         0         2         0' \
        '   Bytes :        31        17         0         0        14         0')"$'\n\n' src ro /S /XD obj /NJH /NP
    chmod 755 ro/sub
fi

echo "e2e: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
