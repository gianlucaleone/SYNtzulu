/*
   Simple C++ startup routine to setup CRT
   SPDX-License-Identifier: Unlicense

   (https://five-embeddev.com/ | http://www.shincbm.com/) 

*/

#include <stdint.h>
#include "peripherals.h"
#define DEV_WRITE(addr, val)    (*((volatile uint32_t *)(addr)) = val)
#define DEV_READ(addr)          (*((volatile uint32_t *)(addr)))

// Generic C function pointer.
typedef void(*function_t)(void) ;

// These symbols are defined by the linker script.
// See linker.lds
extern uint8_t          metal_segment_bss_target_start;
extern uint8_t          metal_segment_bss_target_end;
extern const uint8_t    metal_segment_data_source_start;
extern uint8_t          metal_segment_data_target_start;
extern uint8_t          metal_segment_data_target_end;

/* extern const uint8_t    metal_segment_itim_source_start;
extern uint8_t          metal_segment_itim_target_start;
extern uint8_t          metal_segment_itim_target_end; */

/* extern function_t __init_array_start;
extern function_t __init_array_end;
extern function_t __fini_array_start;
extern function_t __fini_array_end; */

// This function will be placed by the linker script according to the section
// Raw function 'called' by the CPU with no runtime.
extern void _enter(void)  __attribute__ ((naked, section(".init")));

// Entry and exit points as C functions.
extern void _start(void) __attribute__ ((noreturn));
void _Exit(int exit_code) __attribute__ ((noreturn,noinline));

// Standard entry point, no arguments.
extern int main(void);

// The linker script will place this in the reset entry point.
// It will be 'called' with no stack or C runtime configuration.
// NOTE - this only supports a single hart.
// tp will not be initialized
void _enter(void) {
    // Setup SP and GP
    // The locations are defined in the linker script
    __asm__ volatile  (
        ".option push;"
        // The 'norelax' option is critical here.
        // Without 'norelax' the global pointer will
        // be loaded relative to the global pointer!
         ".option norelax;"
        "la    gp, __global_pointer$;"
        ".option pop;"
        "la    sp, _sp;"
        "jal   zero, _start;"
        :  /* output: none %0 */
        : /* input: none */
        : /* clobbers: none */); 
    // This point will not be executed, _start() will be called with no return.
}

// At this point we have a stack and global poiner, but no access to global variables.
void _start(void) {
    // Init memory regions
    // Clear the .bss section (global variables with no initial values)
    for (uint32_t i = 0; 
            i < (&metal_segment_bss_target_end - &metal_segment_bss_target_start);
            i++) {
        ((char*)&metal_segment_bss_target_start)[i] = '\0';
    }
    
    // Initialize the .data section (global variables with initial values)
    for (uint32_t i = 0; 
            i < (&metal_segment_data_target_end - &metal_segment_data_target_start);
            i++) {
        ((char*)&metal_segment_data_target_start)[i] = ((char*)&metal_segment_data_source_start)[i];
    }
    
    int rc = main();

/*     __asm__ volatile ("nop");
    __asm__ volatile ("nop");
    __asm__ volatile ("nop");
    __asm__ volatile ("nop");
    __asm__ volatile ("nop");
    __asm__ volatile ("nop");
    __asm__ volatile ("nop");
    __asm__ volatile ("nop");
    __asm__ volatile ("nop");
    __asm__ volatile ("nop"); */


    while (1);

    _Exit(rc);
}

// This should never be called. Busy loop with the CPU in idle state.
void _Exit(int exit_code) {
    (void)exit_code;
    // Halt
    while (1) {
        __asm__ volatile ("wfi");
    }
}
