OUTPUT_ARCH("riscv")

ENTRY(_enter)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 0x3000/* RAM size 8KB */
}
 
SECTIONS {
	/* Include entry point at start of binary */
	.text : ALIGN(4) {
		KEEP(*(.init));
		*(.text);
	} >RAM
	.bss : ALIGN(4) {
		metal_segment_bss_target_start = .;
		*(.bss);
        metal_segment_bss_target_end = .;
		. += 4096;
		_sp = .;
		. += 4096;
		__global_pointer$ = .;
		bss_end = .;
	} >RAM

	.rodata : ALIGN(4) {
		KEEP(*(.rodata));
	} >RAM

	.data : ALIGN(4) {
        metal_segment_data_target_start = .;
		*(.data);
        metal_segment_data_target_end = .;
	} >RAM
    PROVIDE( metal_segment_data_source_start = LOADADDR(.data) );

}