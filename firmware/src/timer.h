/*
   Simple machine mode timer driver for RISC-V standard timer.
   SPDX-License-Identifier: Unlicense

   (https://five-embeddev.com/) 

*/

#ifndef TIMER_H
#define TIMER_H

#include <stdint.h>

#define RISCV_MTIMECMP_ADDR    (0x80000000)
#define RISCV_MTIME_ADDR       (0x80000000)
/* #define RISCV_MTIMECMP_LO_ADDR (0x80000000)
#define RISCV_MTIMECMP_HI_ADDR (0x80000004)
#define RISCV_MTIME_LO_ADDR    (0x80000008)
#define RISCV_MTIME_HI_ADDR    (0x8000000C) */

#ifndef MTIME_FREQ_HZ
// Timer for iCEBreaker board
#define MTIME_FREQ_HZ 22500000
#endif

#define MTIMER_SECONDS_TO_CLOCKS(SEC)           \
    ((uint32_t)(((SEC)*(MTIME_FREQ_HZ))))

#define MTIMER_MSEC_TO_CLOCKS(MSEC)           \
    ((uint32_t)(((MSEC)*(MTIME_FREQ_HZ))/1000))

#define MTIMER_USEC_TO_CLOCKS(USEC)           \
    ((uint32_t)(((USEC)*((MTIME_FREQ_HZ)/1000))/1000))

/** Set the raw time compare point in system timer clocks.
 * @param clock_offset Time relative to current mtime when 
 * @note The time range of the 64 bit timer is large enough not to consider a wrap around of mtime.
 * An interrupt will be generated at mtime + clock_offset.
 * See http://five-embeddev.com/riscv-isa-manual/latest/machine.html#machine-timer-registers-mtime-and-mtimecmp
 */
void mtimer_set_raw_time_cmp(uint32_t clock_offset);

/** Read the raw time of the system timer in system timer clocks
 */
/* uint64_t mtimer_get_raw_time(void); */
uint32_t mtimer_get_raw_time(void);
            

#endif // #ifdef TIMER_H

