# loup-cmd-robocopy

The Windows `robocopy` command recreated in [Loup](https://code-craft.ai/references/loup):
copy and mirror directory trees with a sync planner (plan, then execute),
a dry run (`/L`), purging of extra files, moves, exclusions, robocopy's job
header, per-directory log, summary table and bit-mask exit codes, on Linux.

Part of the **loup-cmd** series of example applications: classic Linux and
Windows commands, and projects for each Loup execution mode, each in its own
repository under [myronccai](https://github.com/myronccai?tab=repositories&q=loup-cmd).
This one is `host.dual` Loup built as a native binary, and the capstone of
the Windows set. It uses the shared Windows code in [`source/win/`](source/win/)
(switch parser, wildcard matcher, path helpers, messages), copied from
[loup-cmd-type](https://github.com/myronccai/loup-cmd-type).

## Requirements

- [Loup Lite](https://github.com/code-craft-ai-company/loup-releases) 1.26.0
  or later; see [Installing Loup Lite](#installing-loup-lite).
- `make`, and `clang` 17 or later for the native build.

## Installing Loup Lite

This example is built and tested with **Loup Lite**, the free public build of
the Loup toolchain from [Code Craft AI](https://code-craft.ai), meant for
education and training. Code Craft AI publishes the official builds,
installers and signed checksums at
**<https://github.com/code-craft-ai-company/loup-releases>**, for Linux
(x86-64, arm64), macOS (Apple silicon, Intel) and Windows (x86-64).

Linux and macOS:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://github.com/code-craft-ai-company/loup-releases/releases/latest/download/loup-install.ps1 | iex
```

The installer picks the archive for your machine, checks it against the
release's `SHA256SUMS`, unpacks it into `~/.loup`
(`%LOCALAPPDATA%\Programs\Loup` on Windows) and puts its `bin` directory on
your `PATH`; it needs no administrator rights. You get `loup`, the Stage0
compiler `loup-bootstrap` and the Wasm runtime `loup-launcher`. Open a new
shell and check:

```sh
loup --version             # loup 1.26.0 or later
```

CI installs the exact version it tests with, 1.26.0. To do the same:

```sh
curl -fsSL https://github.com/code-craft-ai-company/loup-releases/releases/download/v1.26.0/loup-install.sh | sh -s -- --version 1.26.0
```

To install by hand, download your platform's archive from the
[releases page](https://github.com/code-craft-ai-company/loup-releases/releases),
check it against `SHA256SUMS`, unpack it anywhere and add its `bin` directory to
`PATH`. The [loup-releases README](https://github.com/code-craft-ai-company/loup-releases#verify-a-download)
explains how to verify the Sigstore signature on `SHA256SUMS`.

Loup Lite leaves out Loup's cryptography library and the full set of Loup
packages; this example needs neither. Commercial use of Loup needs a
license: <https://code-craft.ai/loup/license>.

## Usage

```sh
make build                          # native binary: build/robocopy
make ci                             # check, unit tests, build, end-to-end tests
make run ARGS="src dst /MIR /L"     # run from source with loup run
```

Mirror a site into a backup, leaving out `*.tmp` files (the working
directory, an absolute path, is shown here as `\home\me\work`):

```text
$ build/robocopy site backup /MIR /XF '*.tmp'

-------------------------------------------------------------------------------
   ROBOCOPY     ::     Robust File Copy (loup-cmd-robocopy)
-------------------------------------------------------------------------------

  Started : Tuesday, October 20, 2026 1:05:21 AM
   Source : \home\me\work\site\
     Dest : \home\me\work\backup\

    Files : *.*
Exc Files : *.tmp

  Options : *.* /S /E /PURGE /MIR

------------------------------------------------------------------------------

	  New Dir          1	\home\me\work\site\
	    New File  		      12	index.html
100%
	  New Dir          1	\home\me\work\site\css\
	    New File  		       7	main.css
100%
	  New Dir          0	\home\me\work\site\img\
	  New Dir          0	\home\me\work\site\img\empty\

------------------------------------------------------------------------------

               Total    Copied   Skipped  Mismatch    FAILED    Extras
    Dirs :         4         4         0         0         0         0
   Files :         2         2         0         0         0         0
   Bytes :        19        19         0         0         0         0
   Times :   0:00:00   0:00:00                       0:00:00   0:00:00
   Ended : Tuesday, October 20, 2026 1:05:21 AM

```

After `index.html` changes and a stray `old.html` appears in the backup, a
dry run shows what a mirror would do, and the real run does it:

```text
$ build/robocopy site backup /MIR /XF '*.tmp' /L /NJH; echo "exit $?"
	                   1	\home\me\work\site\
	*EXTRA File   		       4	old.html
	    Changed   		      15	index.html
	                   1	\home\me\work\site\css\
	                   0	\home\me\work\site\img\
	                   0	\home\me\work\site\img\empty\

------------------------------------------------------------------------------

               Total    Copied   Skipped  Mismatch    FAILED    Extras
    Dirs :         4         0         4         0         0         0
   Files :         2         1         1         0         0         1
   Bytes :        22        15         7         0         0         4
   Times :   0:00:00   0:00:00                       0:00:00   0:00:00
   Ended : Tuesday, October 20, 2026 1:05:21 AM

exit 3
$ build/robocopy site backup /MIR /XF '*.tmp' /NJH /NJS /NDL /NP; echo "exit $?"
	*EXTRA File   		       4	old.html
	    Changed   		      15	index.html
exit 3
$ build/robocopy site backup /MIR /XF '*.tmp' /NJH /NJS /NDL; echo "exit $?"
exit 0
```

## Switches

| Switch | Meaning |
|---|---|
| `file ...` | Names or wildcards of the files to copy, after the destination (default `*.*`) |
| `/S` | Copy subdirectories, except those with no selected file below them |
| `/E` | Copy subdirectories, including empty ones |
| `/PURGE` | Delete destination files and directories that are not in the source |
| `/MIR` | Mirror: `/E` plus `/PURGE` |
| `/MOV` | Move files: delete each source file once it is copied (or already identical) |
| `/MOVE` | Move files and directories: also remove source directories left empty (not the source root) |
| `/XF name ...` | Exclude files by name or wildcard (neither copied nor purged) |
| `/XD name ...` | Exclude directories by name, wildcard or path |
| `/L` | List only: report and count everything, change nothing |
| `/NP` | No `100%` progress line after each copied file |
| `/NFL`, `/NDL` | No file lines, no directory lines |
| `/NJH`, `/NJS` | No job header, no job summary |
| `/?` | Help |

Switches start with `/` or `-`, in any case; `/XF` and `/XD` take every
following argument up to the next switch. A file "changed" when its size or
content differs (there are no time stamps to compare). Deleting never
follows a symbolic link: a link is unlinked, and a directory is emptied
entry by entry before it is removed.

Exit status, a bit mask: `0` already in sync, `1` files were copied, `2`
extra files or directories were found (purged or not), `4` mismatches (a
file where a directory is, or the reverse), `8` some copies, directory
creations or deletions failed; combinations add up (`3` = copied and
extras). `16`: a fatal error (bad parameter, no source), nothing was done.

## Differences from the original

- Loup 1.26.0 has no file metadata: "changed" means a different size or
  content, so both files are read; there are no `Newer`/`Older`/`Tweaked`
  lines, no `/XO`, `/MAXAGE` or `/MINAGE`, and no attributes, times or
  security are copied (`/COPY`, `/DCOPY`, `/SEC` are not supported).
- No retries (`/R`, `/W`): a failure is reported once, as with `/R:0`. No
  `/MT`, `/LOG`, `/TEE`, `/V`, `/Z`, `/B`.
- The header names this program instead of Windows and shows the switches
  given rather than robocopy's defaults; there are no speed lines; sizes
  are plain byte counts (no `k`/`m`/`g`); the `Times` row shows the job's
  elapsed time for Total and Copied and `0:00:00` elsewhere; progress is
  one `100%` line per copied file. Column widths follow robocopy's layout
  as closely as known.
- Files inside an extra directory are neither listed nor counted; the
  directory counts once.
- Dot-files are copied like any other file (Linux has no hidden attribute).
- Parameter errors go to standard error without the header; per-file
  errors are part of the log on standard output.
- File names are case-sensitive on Linux; wildcards ignore case. Paths are
  printed absolute, with `\`.
- An unreadable source file (permissions) stops the program with the
  toolchain's `IoError` message: a native `IoError` cannot be caught.
- `/?` prints a short summary written for this project. `--help` and
  `--version` as the only argument are series conventions.

## Layout

```text
source/main.loup                 # entry point
source/appinfo.loup              # name, version, exit bits
source/cli/args.loup             # robocopy's switches via win.switches, file patterns
source/cli/usage.loup            # /? and --version text
source/cli/app.loup              # run(): parse, fatal errors, dispatch
source/commands/plan.loup        # the sync planner: actions for every directory and file
source/commands/execute.loup     # carries the plan out: copies, purges, moves, counts
source/commands/report.loup      # header, log lines, summary table, error lines
source/commands/robocopy.loup    # run_robocopy: header, plan, execute, summary, exit bits
source/commands/clock.loup       # times for the header and the summary
source/commands/fspaths.loup     # current directory, absolute paths
source/win/                      # shared Windows code: switches, wildcards, paths, messages
tests/*_test.loup                # unit tests (make test)
tests/e2e.sh                     # end-to-end tests of build/robocopy (make e2e)
specs/robocopy/                  # requirements, design, tasks
```

[AGENTS.md](AGENTS.md) has every build and test command and the conventions
for changing the code.

## License

[MIT](LICENSE), copyright 2026 Code Craft AI LLC. The Loup skill in
[`skills/loup-programmer/`](skills/loup-programmer/) is copied from the Loup
project and is not covered by this license; it keeps the Loup project's terms.
