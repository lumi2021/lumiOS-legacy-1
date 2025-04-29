# LumiOS Kernel

This is the kernel.
It does uhhh... kernel things.

## Routes:
[`boot`](boot/)
[`debug`](debug/)
[`drivers`](drivers/)
[`fs`](fs/)
[`gl`](gl/)
[`io`](io/)
[`memory`](memory/)
[`sysprocs`](sysprocs/)
[`system`](system/)
[`theading`](theading/)
[`utils`](utils/)

## Files:

### [`config.zig`](config.zig)

Kernel's general configurations.
Must be set before build as it only takes effect
during comptime.

### [`interruptions.zig`](interruptions.zig)

Kernel's general interruptions list and implementations.

### [`main.zig`](main.zig)

Kernel's logical entry point. (for real entry point, see [`boot/`](boot/))
It calls memory, interruptions, timer, and schedue configurations,
then halts the system so the scheduler can take control of it.

### [`os.zig`](os.zig)

Namespaces and routes (see [Routes](#routes) for more info).

### [`syscalls.zig`](syscalls.zig)

Kernel's system calls list.
