TOOLCHAIN_PREFIX=riscv32-unknown-elf-

# List of source files
SRCS = src/main.c src/startup.c src/timer.c

# List of header files
HDRS = src/riscv-csr.h src/riscv-interrupts.h src/timer.h src/peripherls.h

# Object files derived from source files
OBJS = $(SRCS:.c=.o)

# Default target: build the executable
all: exe.hex

exe.hex: exe.bin
	python3 makehex.py $< > $@
	rm exe.bin

exe.bin: exe.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@
	rm exe.elf
	rm src/*.o

# Build the executable
exe.elf: $(OBJS)
	$(TOOLCHAIN_PREFIX)gcc -nostartfiles -march=rv32i_zicsr -mabi=ilp32 $(OBJS) -o exe.elf -T src/linker.lds

# Compile source files to object files
%.o: %.c
	$(TOOLCHAIN_PREFIX)gcc -march=rv32i_zicsr -mabi=ilp32 -O3 -c $< -o $@

# Generate assembly code from a source file
%.s: %.c
	$(TOOLCHAIN_PREFIX)gcc -march=rv32i -mabi=ilp32 -O3 -S $< -o $@

# Targets for switching applications
compile:
	@if [ -z "$(app)" ]; then \
		echo "Usage: make compile app=<application_name>"; \
		exit 1; \
	fi
	cp src/applications/$(app)/* src/
	$(MAKE) all

# Clean up generated files
clean:
	rm -f $(OBJS) exe.elf exe.bin exe.hex

.PHONY: all clean

