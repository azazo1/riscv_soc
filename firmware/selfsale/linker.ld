ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 8K
    RAM (rwx) : ORIGIN = 0x0000f000, LENGTH = 4K
}

SECTIONS
{
    .text : {
        KEEP(*(.text.startup))
        *(.text*)
    } > ROM

    .rodata : {
        *(.srodata*)
        *(.rodata*)
    } > ROM

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

    ASSERT(_sdata == _edata, "selfsale firmware does not use initialized data")

    /DISCARD/ : {
        *(.comment)
        *(.riscv.attributes)
        *(.eh_frame)
    }
}
