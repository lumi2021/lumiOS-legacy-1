# Lumi shell

Lush (abreviation for lumi shell) is the operating system general shell.
Commands can be requested to it by calling `execute()` in [shell.zig](shell.zig).

## Lush commands sheet:

| Command | Description |
|:--|:--|
| `cls`           | Clears the terminal history. |
| `lsdir <?path>` | Lists directories in provided path. if `path` is not provided, it will list the drives and pseudodrives in the system. |
| `lstask`        | Lists active tasks, task ids and current task states. |
| `reboot`        | Requests a system reboot. |
| `shutdown`      | Requests a system shutdown. |
