/*
   Simple machine mode timer driver for RISC-V standard timer.
   SPDX-License-Identifier: Unlicense

   (https://five-embeddev.com/) 

*/
#include "timer.h"

/* void mtimer_set_raw_time_cmp(uint32_t clock_offset) {
    uint64_t new_mtimecmp = mtimer_get_raw_time() + (uint64_t) clock_offset;

    *((volatile uint32_t *)(RISCV_MTIMECMP_LO_ADDR)) = (uint32_t) (new_mtimecmp & 0xFFFFFFFF);
    *((volatile uint32_t *)(RISCV_MTIMECMP_HI_ADDR)) = (uint32_t) ((new_mtimecmp>>32) & 0xFFFFFFFF);
} */

inline void mtimer_set_raw_time_cmp(uint32_t clock_offset) {
    /* uint32_t new_mtimecmp = mtimer_get_raw_time() + clock_offset;

    *((volatile uint32_t *)(RISCV_MTIMECMP_ADDR)) = new_mtimecmp; */
   *((volatile uint32_t *)(RISCV_MTIMECMP_ADDR)) = clock_offset;
}
 
/*
* Read the raw time of the system timer in system timer clocks
*/
/* uint64_t mtimer_get_raw_time(void) {
    uint64_t mtime;
    mtime = (uint64_t) (((uint64_t)*((volatile uint32_t *)(RISCV_MTIME_HI_ADDR))) << 32) | 
                                  (*((volatile uint32_t *)(RISCV_MTIME_LO_ADDR)));
    return mtime;
}  */

uint32_t mtimer_get_raw_time(void) {
    return (*((volatile uint32_t *)(RISCV_MTIME_ADDR)));
}