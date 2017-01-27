OUTPUT_ARCH(i386)

SECTIONS
{
    . = 0;
    .init : { *(.init) }
    . = ALIGN(16);
    .text : { *(.text.startup) *(.text) *(.text.*) }
    . = ALIGN(16);
    .data : { *(.data) }
    . = ALIGN(16);
    .rodata : { *(.rodata) }
    . = ALIGN(16);
    .bss : { *(.bss) }
}

ENTRY(start)
