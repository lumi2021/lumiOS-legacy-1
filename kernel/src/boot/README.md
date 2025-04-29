# /src/boot/

This directory is basically a trash bin for things that
are used once right after the kernel boots.

## Files:
### [boot_entry.zig](boot_entry.zig)

In this file there is the real main function (`__boot_entry__()`). This file I
comunicates with the limine protocoll to prepare the basic environment for the
kernel main function in [/kernel/src/main.zig](/kernel/src/main.zig).

### [boot_info.zig](boot_info.zig)

Structures that stores boot information.

### [limine.zig](limine.zig)

Limine library.
