OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  dram (rwx) : ORIGIN = 0x80200000, LENGTH = 1M
}

SECTIONS
{
  .text : {
    *(.text*)
  } > dram

  .rodata : {
    *(.rodata*)
  } > dram

  .data : {
    *(.data*)
  } > dram

  .bss : {
    *(.bss*)
    *(COMMON)
  } > dram
}
