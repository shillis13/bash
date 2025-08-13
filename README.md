# Bash Scripting Framework

This repository contains a modular framework for building robust Bash scripts and a collection of utility programs.

## Framework

The `libs/` directory provides reusable modules:

- `lib_main.sh`: orchestrates library loading, argument definition, and script initialization.
- `lib_cmdArgs.sh`: parse command-line arguments with `libCmd_add` and `libCmd_parse`.
- `lib_logging.sh`: colored logging with levels and optional file output.
- `lib_command.sh`: safe command execution with dry-run support.
- Additional helpers: `lib_utils.sh`, `lib_types.sh`, `lib_grep.sh`, `lib_stackTrace.sh`, and more.

Scripts load the framework by sourcing `libs/lib_main.sh` and then calling `initializeScript` after declaring any additional options.

### Creating a Script

```bash
#!/usr/bin/env bash
# Path to libraries relative to this script
source "$(dirname "${BASH_SOURCE[0]}")/libs/lib_main.sh"

# Declare script-specific options
define_arguments() {
    libCmd_add -t value --long name -v "name" -u "Name to greet"
}

main() {
    log_always "Hello $name"
}

initializeScript "$@"
main "$@"
```

`initializeScript` loads dependencies, defines built-in options, parses the command line, and applies library hooks. Logging, command execution, and other helpers become available once initialization completes.

## Utility Scripts

The repository includes a number of standalone utilities that use the framework:

- `grep.sh` – friendly wrapper around `grep` with framework logging and argument parsing.
- `gpush.sh` – helper for pushing Git branches.
- `host_info.sh` – collect system information using the logging and command modules.
- `findFiles.sh`, `renameFiles.sh`, `find_items.sh` and others – file and system helpers.

Treat these scripts as examples of how to integrate the libraries into real tasks.

## Running Tests

Unit tests live under `tests/`. Execute all suites with:

```bash
./tests/run_tests.sh
```

Specify a single suite with `--test <name>` to run a specific `test_<name>.sh` file.

```bash
./tests/run_tests.sh --test logging
```
