/* Starts at 1M (0x100000). */
KERNEL_PHYS_START = 1M;
KERNEL_STACK_SIZE = 0x4000;

ENTRY(_start)

SECTIONS {

    /* . = -2048M; */
    . = KERNEL_PHYS_START;
    
    __base__ = .;
    __kernel_start__ = .;

    .text . : ALIGN(4K) {
        *(.text*)
    }

    .rodata : ALIGN(4K) {
        *(.rodata*)
    }

    .data : ALIGN(4K) {
        *(.data*)
    }

    .bss : ALIGN(4K) {
        *(COMMON)
        *(.bss*)

        . = ALIGN(16);
        . += KERNEL_STACK_SIZE;
    }

    __kernel_end__ = .;
}
