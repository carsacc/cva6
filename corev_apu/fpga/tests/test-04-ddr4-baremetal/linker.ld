OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  dram (rwx) : ORIGIN = 0x80000000, LENGTH = 1M
}

SECTIONS
{
  . = ORIGIN(dram);
  .text : {
    *(.text.init)
    *(.text*)
  } > dram

  .rodata : {
    *(.rodata*)
  } > dram

  .data ALIGN(8) : {
    *(.sdata*)
    *(.data*)
  } > dram

  .bss ALIGN(8) : {
    __bss_start = .;
    *(.sbss*)
    *(.bss*)
    *(COMMON)
    . = ALIGN(8);
    __bss_end = .;
  } > dram

  . = ALIGN(16);
  _stack_top = ORIGIN(dram) + LENGTH(dram);
}
