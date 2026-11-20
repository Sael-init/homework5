    .option norvc
    .text
    .globl _start
_start:
    lui  t0, 0x1
    addi t1, zero, -128
    sw   t1, 0(t0)
    lb   t2, 0(t0)
    lbu  s0, 0(t0)
    lh   s1, 0(t0)
    lhu  a0, 0(t0)
    ebreak
