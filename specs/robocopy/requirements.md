# Requirements: robocopy

## Introduction

`robocopy` ("robust file copy") is the Windows command for copying and
mirroring directory trees: it compares a source tree with a destination,
copies what is new or changed, can delete what is no longer in the source,
and reports everything in a job log with a summary table and an exit code
that is a bit mask. This repository recreates its core in Loup for Linux as
the capstone of the Windows set: a sync planner (plan, then execute), a dry
run (`/L`), careful deletion, and robocopy's output and exit codes. It uses
the shared Windows code in `source/win/`.

## Requirements

### Requirement 1: Sync

**User Story:** As an administrator, I want `robocopy src dst /MIR` to make
the destination match the source.

#### Acceptance Criteria

1. THE program SHALL copy every source file that is missing in the
   destination ("New File") or differs from it in size or content
   ("Changed"), and SHALL skip identical files.
2. WITHOUT `/S` or `/E` THE program SHALL process only the top directory;
   WITH `/S` also every subdirectory that holds a selected file somewhere
   below it; WITH `/E` every subdirectory, empty or not.
3. THE program SHALL report destination files and directories that are not
   in the source as `*EXTRA File` and `*EXTRA Dir`; WITH `/PURGE` or `/MIR`
   (= `/E /PURGE`) it SHALL delete them.
4. Deleting SHALL never follow a symbolic link: a link is unlinked, a real
   directory is emptied entry by entry and then removed.
5. THE program SHALL report a source file whose destination name is a
   directory, or a source directory whose destination name is a file, as a
   mismatch, and leave both alone.
6. WHEN the destination is inside the source, THE program SHALL not copy
   the destination into itself.
7. `/MOV` SHALL delete each source file once it is copied (or found
   identical); `/MOVE` SHALL also remove source directories left empty,
   except the source root.

### Requirement 2: Selection

**User Story:** As an administrator, I want to choose which files take part.

#### Acceptance Criteria

1. File operands after the destination SHALL select files by name or
   wildcard (default `*.*`), in the source and among the extras.
2. `/XF` SHALL exclude files by name or wildcard, and `/XD` directories by
   name, wildcard or path; excluded entries are neither copied nor purged.
3. Wildcards SHALL follow Windows rules and ignore case.

### Requirement 3: Output

**User Story:** As an administrator, I want robocopy's job log.

#### Acceptance Criteria

1. Unless `/NJH`, THE program SHALL print the job header: start time,
   source and destination (absolute, with `\` and a final `\`), the file
   patterns, `Exc Files`/`Exc Dirs`, and the options.
2. FOR each directory it processes THE program SHALL print a line with its
   status (`New Dir`, blank for an existing one, `*EXTRA Dir`, `*MISMATCH`),
   its number of selected files and its path, unless `/NDL`.
3. FOR each file copied, extra or mismatched THE program SHALL print a line
   with its status, size and name, unless `/NFL`; identical files are not
   listed. After each copied file it SHALL print `100%` unless `/NP`.
4. Unless `/NJS`, THE program SHALL print the summary table: rows `Dirs`,
   `Files`, `Bytes`; columns `Total`, `Copied`, `Skipped`, `Mismatch`,
   `FAILED`, `Extras` (Total excludes extras); then `Times` and `Ended`.
5. `/L` SHALL print and count everything as if the job ran, and change
   nothing.
6. WHEN a copy, a directory creation or a deletion fails, THE program SHALL
   print a time-stamped `ERROR 5 (0x00000005) ...` line and
   `Access is denied.`, count it as FAILED and go on.

### Requirement 4: Exit status

**User Story:** As a script author, I want robocopy's bit mask.

#### Acceptance Criteria

1. THE exit status SHALL be the sum of 1 (files copied), 2 (extras found),
   4 (mismatches), 8 (failures); 0 means the trees were already in sync.
2. WHEN the source directory does not exist, THE program SHALL print the
   header, `ERROR 2 (0x00000002) Accessing Source Directory X\` and
   `The system cannot find the file specified.`, and exit 16.
3. WHEN a parameter is invalid (an unknown switch, a path among the file
   names, `/XF` or `/XD` without names), THE program SHALL print
   `ERROR : Invalid Parameter #N : "X"` on standard error and exit 16; with
   no destination, `ERROR : No Destination Directory Specified.`; with no
   arguments, the help text; each with exit 16.
4. `/?` SHALL print a short help text and exit 0; `--version` alone SHALL
   print `robocopy (loup-cmd-robocopy) 0.1.0`.
