# Design: robocopy

## Overview

`main()` passes `runtime.args()` to `cli.app.run`, which parses them
(`cli.args` on top of `win.switches`), handles `/?`, `--version` and the
fatal parameter errors, and calls `commands.robocopy.run_robocopy`. That
prints the job header, checks the source, **plans** the whole job
(`commands.plan.plan`: a list of actions, nothing written), **executes** it
(`commands.execute.execute`: prints each line, copies, deletes, counts), and
prints the summary. With `/L` the executor prints and counts but changes
nothing, so a dry run shows exactly what a real run would do.

## Modules

| Module | Contents |
|---|---|
| `source/appinfo.loup` | name, version, the exit bits 1, 2, 4, 8 and 16 |
| `source/cli/args.loup` | `Options`, `robocopy_switches()`, `parse_args`, `file_patterns`, `option_words` |
| `source/cli/usage.loup` | `usage()` (a short `/?` summary), `version_line()` |
| `source/cli/app.loup` | `run()`: parse, help/version, missing operands, `run_robocopy` |
| `source/commands/plan.loup` | `Action` and its kinds, `file_selected`, `dir_excluded`, `same_content`, `has_files`, `plan` |
| `source/commands/execute.loup` | `Flags`, `execute`, `delete_tree`, `copy_checked`, `make_dir`, `remove_moved_dirs` |
| `source/commands/report.loup` | `Stats` and `bump`, line formats, `header_lines`, `summary_lines`, `error_lines` |
| `source/commands/robocopy.loup` | `run_robocopy`, `exit_bits` |
| `source/commands/clock.loup` | times from `date` through `io.proc`, `format_elapsed` |
| `source/commands/fspaths.loup` | `current_dir` (via `pwd`), `absolute_path`, `is_within` |
| `source/win/` | the shared Windows code: switches, wildcards, paths, messages |

### The plan

`plan_dir` handles one directory pair and recurses (depth first, name
order, at most `MAX_DEPTH` levels):

1. the source's selected files (patterns, not `/XF`) and subdirectories
   (not `/XD`, never the destination root itself);
2. a directory action: `A_DIR_NEW`, `A_DIR_SAME`, or `A_DIR_MISMATCH` when a
   file has the name in the destination (nothing below it is planned);
3. the destination's extras: selected files that are neither a source file
   nor a source directory, and directories that are neither, not excluded,
   and do not contain the source;
4. the files: `A_FILE_NEW`, `A_FILE_SAME` / `A_FILE_CHANGED` (the bytes are
   compared: Loup 1.26.0 has no time stamps, T1), or `A_FILE_MISMATCH` when
   a directory has the name;
5. with `/S`, each subdirectory that `has_files` below it; with `/E`, all.

Each `Action` holds its kind, source and destination paths, name, and size
(bytes for files, the number of selected files for directories).

### Execution

`execute` walks the actions in order with `Flags` (scalars only). New
directories are created; files are copied with `copy_checked` (creates the
parent, refuses a directory in the way, copies, then checks that the
destination exists with the right size); extras are deleted with
`delete_tree` under `/PURGE`. `/MOV` deletes a source file after a good copy
or when it was identical; `/MOVE` then removes emptied source directories
deepest first (`remove_moved_dirs`), never the source root. Every failure
prints two error lines and counts as FAILED; the job goes on (no retries).

`delete_tree` deletes a directory's entries one by one and removes the
directory only once `listDir` shows it empty. A symbolic link (`test -h`
through `io.proc`, since `io.fs` follows links) is only unlinked, never
entered: Loup 1.26.0's native `removeDir` follows links, so calling it on a
link or a non-empty tree could delete files outside the destination.

### Output

`report.loup` formats the header (`Started`, `Source`, `Dest`, `Files`,
`Exc Files`, `Exc Dirs`, `Options`, between rules), directory lines
(`\t` + status in 11 columns + count in 9 + `\t` + path), file lines (`\t` +
status in 14 + `\t\t` + size in 8 + `\t` + name), error lines, and the
table: each value right-aligned in 10 columns after the 10-column label;
Total = Copied + Skipped + Mismatch + FAILED. `exit_bits` combines 1 (files
copied), 2 (extra files or directories), 4 (mismatches), 8 (failures).

### Native-build notes

- `pad` helpers copy their argument first (`var out = "" + text;`):
  reassigning a var that still shares a string literal argument crashed the
  native build when several such calls were combined in one expression.
- `Stats` (lists) and the action list are passed as `edits` or as lists;
  `Flags` holds scalars only (a struct holding a list is copied on every
  call natively). Structs are built only in their defining modules.
- There is no `cwd()` or clock with dates in native builds that this uses:
  the current directory comes from `pwd`, times from `date`.

## Differences from the original

- "Changed" means a different size or content (both files are read), not a
  newer time stamp, so there are no `Newer`, `Older` or `Tweaked` lines and
  no `/XO`, `/MAXAGE`, `/MINAGE`; no attributes, security or timestamps are
  copied (`/COPY`, `/DCOPY`, `/SEC` are not supported), nor `/R`, `/W`
  retries (a failure is reported once), `/MT`, `/LOG`, `/TEE`, `/V`.
- The header names this program instead of Windows, shows the switches
  given (not robocopy's defaults such as `/R:1000000 /W:30`), and has no
  speed lines; sizes are plain byte counts (no `k`/`m`/`g`); the `Times` row
  shows the job's elapsed time for Total and Copied and `0:00:00` otherwise.
- Progress is a single `100%` line per copied file.
- Files inside an extra directory are not listed or counted; the directory
  counts once as an extra.
- Hidden files are copied like any other (dot-files have no special
  meaning here).
- Parameter errors go to standard error without the header; per-file
  errors are part of the log on standard output.
- File names are case-sensitive on Linux; wildcards ignore case.
- An unreadable source file (permissions) stops the program with the
  toolchain's `IoError` message.

## Error handling

Parameter errors and a missing source end the job before anything changes
(exit 16). Everything else is reported per entry and the job continues.

## Testing

- `tests/args_test.loup`: switches, implied switches, lists, invalid
  parameters, the Options line.
- `tests/plan_test.loup`: filters, action kinds and order (same, changed,
  extra, mismatch), `/S` vs `/E`, `/XD`, a destination inside the source.
- `tests/report_test.loup`: line formats, the table, the header, elapsed
  times.
- `tests/robocopy_test.loup`: whole runs (copy, in sync, extras, `/L`,
  `/MIR`, changed files, `/MOVE`, mismatches, fatal errors) and helpers.
- `tests/e2e.sh`: the native binary on fixture trees under `$TMP`: the full
  log (paths and times normalised), the resulting trees, symbolic links
  that a purge must not follow, `/MOVE` and `/MOV`, mismatches, a missing
  source, and write failures (skipped as root).
