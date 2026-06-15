ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00008000, LENGTH = 32K
}

SECTIONS
{
    .text : {
        KEEP(*(.text.startup))
        *(.text*)
    } > RAM

    .rodata : {
        *(.srodata*)
        *(.rodata*)
    } > RAM

    .data : {
        . = ALIGN(4);
        _sdata = .;
        *(.sdata*)
        *(.data*)
        . = ALIGN(4);
        _edata = .;
    } > RAM

    .bss (NOLOAD) : {
        . = ALIGN(4);
        _sbss = .;
        *(.sbss*)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > RAM

    _stack_top = ORIGIN(RAM) + LENGTH(RAM);

    /DISCARD/ : {
        *(.comment)
        *(.riscv.attributes)
        *(.eh_frame)
    }
}
