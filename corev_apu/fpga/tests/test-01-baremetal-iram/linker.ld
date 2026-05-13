OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
  iram (rwx) : ORIGIN = 0x80000000, LENGTH = 1M
}

SECTIONS
{
  . = ORIGIN(iram);
  .text : {
    *(.text.init)
    *(.text*)
  } > iram

  .rodata : {
    *(.rodata*)
  } > iram

  .data ALIGN(8) : {
    *(.sdata*)
    *(.data*)
  } > iram

  .bss : {
    *(.sbss*)
    *(.bss*)
    *(COMMON)
  } > iram

  . = ALIGN(16);
  _stack_top = ORIGIN(iram) + LENGTH(iram);
}
