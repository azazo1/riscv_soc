.section .text.startup
.globl _start
_start:
    lui sp, %hi(_stack_top)
    addi sp, sp, %lo(_stack_top)

    lui t0, %hi(_sbss)
    addi t0, t0, %lo(_sbss)
    lui t1, %hi(_ebss)
    addi t1, t1, %lo(_ebss)

clear_bss:
    beq t0, t1, call_main
    sw zero, 0(t0)
    addi t0, t0, 4
    beq zero, zero, clear_bss

call_main:
    jal ra, main

hang:
    beq zero, zero, hang
