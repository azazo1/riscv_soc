ENTRY(_start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 32K   // 指令/只读数据, 从地址 0 开始
    RAM (rwx) : ORIGIN = 0x00008000, LENGTH = 1K    // 读写数据, 偏移 32K 后
}

SECTIONS
{
    // 代码段: 放到 ROM
    .text : {
        KEEP(*(.text.startup))  // 启动代码, 防止被 gc 回收
        *(.text*)
    } > ROM

    // 只读数据段: 放到 ROM
    .rodata : {
        *(.srodata*)             // small read-only data (RISC-V ABI)
        *(.rodata*)
    } > ROM

    // 已初始化数据段: 放到 RAM, C 运行时需从 ROM 拷贝
    .data : {
        . = ALIGN(4);
        _sdata = .;              // data 段起始地址, 供启动代码引用
        *(.sdata*)               // small data (RISC-V ABI)
        *(.data*)
        . = ALIGN(4);
        _edata = .;              // data 段结束地址
    } > RAM

    // BSS 段: 未初始化全局变量, 不占用 ROM 空间 (NOLOAD)
    .bss (NOLOAD) : {
        . = ALIGN(4);
        _sbss = .;               // bss 段起始地址, 启动代码清零用
        *(.sbss*)                // small bss (RISC-V ABI)
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;               // bss 段结束地址
    } > RAM

    // 栈顶: RAM 的最高地址
    _stack_top = ORIGIN(RAM) + LENGTH(RAM);

    // 断言: 当前不支持已初始化的 data, 确保 data 段为空
    ASSERT(_sdata == _edata, "c_demo does not support initialized data yet")

    // 丢弃不需要的 sections
    /DISCARD/ : {
        *(.comment)
        *(.riscv.attributes)
        *(.eh_frame)
    }
}
