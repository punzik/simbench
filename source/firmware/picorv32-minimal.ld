MEMORY { ram (rx) : ORIGIN = 0, LENGTH = 65536 }

SECTIONS
{
    . = 0x00;

    .text : {
        *(.init*)
        *(.text*)
    } > ram

    .bss (NOLOAD) :
    {
        *(.bss*)
        *(COMMON)
    } > ram

    .data :
    {
        *(.data*)
    } > ram

    .stack (NOLOAD) :
    {
        /*
        . = ALIGN(4);
        . = . + STACK_SIZE;
        */

        . = ORIGIN(ram) + LENGTH(ram) - 4;
        . = ALIGN(4);
        __stack_top = .;
    } > ram
}
