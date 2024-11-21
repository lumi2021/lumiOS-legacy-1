KERNEL_VIRT_START = 0xffffffff80000000;
KERNEL_STACK_SIZE = 0x4000;

ENTRY(__boot_entry__)

SECTIONS {

    . = KERNEL_VIRT_START;
    
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
