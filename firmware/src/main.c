/*
   
   This firmware is written for SYNtzulu: A Tiny RISC-V-Controlled SNN
   Processor for Real-Time Sensor Data Analysis on Low-Power FPGAs.

   Baremetal main program with timer interrupt.

   This firmware demonstrates a baremetal implementation of a simple 
   RISC-V program with a timer-based interrupt mechanism. It manages 
   synaptic weight loading, sample loading, inference execution, 
   and result transmission via UART.

   Designed for educational and experimental purposes.
*/

#include <stdint.h>

// RISC-V CSR definitions and access classes
#include "riscv-csr.h"
#include "riscv-interrupts.h"
#include "timer.h"
#include "peripherals.h"
#include "constants.h"

#define DEV_WRITE(addr, val)    (*((volatile uint32_t *)(addr)) = val)
#define DEV_READ(addr)          (*((volatile uint32_t *)(addr)))

// timer isr
static void irq_entry(void);

// Load SNN weight or sample
static void load_data(uint32_t spi_addr, uint32_t snn_addr, uint32_t spi_read_size); // blocking

// Load SNN sample (assuming snn_addr and spi_read_size are kept from the settings in main() )
static void load_sample(uint32_t spi_addr);
static void load_inference(uint32_t spi_addr);

// Read SNN inference via UART
static void read_inference(uint32_t inference_addr);
inline static void uart_send(uint32_t data);

// Read sample mem
static void read_sample_mem();
// send inference 
static void send_inference();

// sample address
volatile uint32_t sample_addr = 0;

int main(void) {
	// enable clocks	
	DEV_WRITE(CLOCK_GATING, 0);     

	// Global interrupt disable
    clear_csr(mstatus, MSTATUS_MIE_BIT_MASK);
    write_csr(mie, 0);
	
    // Setup the IRQ handler entry point
    write_csr(mtvec, ((uint_xlen_t) irq_entry));
	
	// wait for uButton to be pressed on iCEBreaker board
	DEV_WRITE(SERVANT_GPIO_ADDR,0xaaaaaaaa);
	while(DEV_READ(SERVANT_GPIO_ADDR) & 0xf0000000);
	DEV_WRITE(SERVANT_GPIO_ADDR,0x55555555);

    // Load synaptic weights from flash
    load_data(WEIGHT_1_ADDR, 1, WEIGHT_DEPTH);
    load_data(WEIGHT_2_ADDR, 2, WEIGHT_DEPTH);
    load_data(WEIGHT_3_ADDR, 3, WEIGHT_DEPTH);
    load_data(WEIGHT_4_ADDR, 4, WEIGHT_DEPTH);

	// load data of first time step
	load_data(SAMPLE_ADDR,   5,  CHANNELS);
    sample_addr = SAMPLE_ADDR + CHANNELS;
	
	// tx first inference
	send_inference();	

    // Setup timer at every sample time 
	mtimer_set_raw_time_cmp(TIME);
    // Enable MIE.MTI
    set_csr(mie, MIE_MTI_BIT_MASK);
    // Global interrupt enable 
    set_csr(mstatus, MSTATUS_MIE_BIT_MASK);

    while (1);
    
    return 0;
}

static void irq_entry(void)  {	

	// enable clocks	
	DEV_WRITE(CLOCK_GATING, 0);

	// Load new samples
	DEV_WRITE(SPI_ADDR, sample_addr);
    DEV_WRITE(SPI_START_ADDR, 1);
	sample_addr += CHANNELS;

	// wait for inference to be computed
	while(DEV_READ(VALID_INFERENCE) == 0); 

	// tx inference via uart
	int volatile potential;
	int i;		
	for(i=0;i<8*4;i=i+4) {
			potential = DEV_READ(V_INFERENCE+i); 
			uart_send(potential>>8);			
			uart_send(potential);			
			uart_send(potential>>24);			
			uart_send(potential>>16);		
	}
	DEV_WRITE(VALID_INFERENCE_RST,1);		
	DEV_WRITE(VALID_INFERENCE_RST,0);

	// turn high-frequency oscillator off
	DEV_WRITE(CLOCK_GATING, GATE_SERV);
	DEV_WRITE(CLOCK_GATING, GATE_GENERAL);
   	
}

static void load_data(uint32_t spi_addr, uint32_t snn_addr, uint32_t spi_read_size) {
    DEV_WRITE(SPI_ADDR, spi_addr);
    DEV_WRITE(SNN_ADDR, snn_addr);
    DEV_WRITE(SPI_READ_SIZE_ADDR, spi_read_size);
    DEV_WRITE(SPI_START_ADDR, 1);
    while(DEV_READ(SPI_START_ADDR));
}

inline static void load_sample(uint32_t spi_addr) {
    DEV_WRITE(SPI_ADDR, spi_addr);
    DEV_WRITE(SPI_START_ADDR, 1);
}

inline static void uart_send(uint32_t data) {
	DEV_WRITE(UART_DATA_ADDR, data);
    DEV_WRITE(UART_SEND_ADDR, 1);
    while(!DEV_READ(UART_READY_ADDR));
}

inline static void read_inference(uint32_t inference_addr) {
    uint16_t inference = (uint16_t)DEV_READ(inference_addr);
    DEV_WRITE(UART_DATA_ADDR, inference>>8);
    DEV_WRITE(UART_SEND_ADDR, 1);
    while(!DEV_READ(UART_READY_ADDR));
    DEV_WRITE(UART_DATA_ADDR, inference);
    DEV_WRITE(UART_SEND_ADDR, 1);
    while(!DEV_READ(UART_READY_ADDR));
}

inline static void load_inference(uint32_t inference_addr) {
    uint16_t inference = (uint16_t)DEV_READ(inference_addr);
    DEV_WRITE(UART_DATA_ADDR, inference>>8);
    DEV_WRITE(UART_DATA_ADDR, inference);
}

static void read_sample_mem() {
	uint32_t k,dummy; 
		for(k=0;k<8*4;k=k+4) {
			dummy = DEV_READ(SAMPLE_MEM+k);
			uart_send(dummy>>8);
			uart_send(dummy); 
		}
}

static void send_inference() {
	while(DEV_READ(VALID_INFERENCE) == 0);
	int volatile potential;
	int i;		
	for(i=0;i<8*4;i=i+4) {
			potential = DEV_READ(V_INFERENCE+i); 
			uart_send(potential>>8);			
			uart_send(potential);			
			uart_send(potential>>24);			
			uart_send(potential>>16);		
		}
	DEV_WRITE(VALID_INFERENCE_RST,1);		
	DEV_WRITE(VALID_INFERENCE_RST,0);
}
