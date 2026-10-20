# Tasks: robocopy

- [x] 1. Copy the shared Windows code into `source/win/` with its tests
  - _Requirements: 2.3_
- [x] 2. Parse the command line: source, destination, file patterns, switches, /XF and /XD lists
  - _Requirements: 2.1, 2.2, 4.3, 4.4_
- [x] 3. The planner: directory and file actions, extras, mismatches, /S vs /E, exclusions
  - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.6, 2.1, 2.2_
- [x] 4. The executor: checked copies, safe deletion, /MOV and /MOVE, /L
  - _Requirements: 1.3, 1.4, 1.7, 3.5, 3.6_
- [x] 5. The job header, directory and file lines, the summary table
  - _Requirements: 3.1, 3.2, 3.3, 3.4_
- [x] 6. Exit bit mask and fatal errors
  - _Requirements: 4.1, 4.2, 4.3_
- [x] 7. Unit tests and end-to-end tests of the native binary (fixtures under `$TMP`)
  - _Requirements: all_
