# Apotheosis

#### /!\\ Do not use Apotheosis yet, it is incomplete /!\\

This repository hosts a build environment for the Apotheosis operating system.

Clone this repository and run `assemble.sh`.  You'll need Lua 5.3 or newer, bash, and probably a Unix-like system due to heavy dependence on `io.popen` and Unix-like commands throughout the build process.  Only tested on Linux.

If you intend to do development work, run `setup.sh` first.

`push-repos.sh` pushes all four repositories to GitHub.  It is intended for my personal use only.

## Project status
- [ ] Apotheosis core
  - [ ] Paragon
    - [X] core kernel
    - [X] multi-user
    - [X] process-based scheduler
    - [X] filesystem abstraction
    - [-] standard Lua emulation (~85%)
    - [X] full VT100 emulation
    - [ ] security features
    - [ ] at least one unmanaged filesystem driver
  - [ ] Epitome
    - [ ] services
    - [ ] scripts
    - [ ] runlevels
  - [ ] Coreutils
    - [ ] basic shell utilities
    - [ ] package manager
