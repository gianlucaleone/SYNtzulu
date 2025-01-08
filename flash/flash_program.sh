#!/bin/bash

# Check if the application name is passed
if [ -z "$1" ]; then
    echo "Usage: $0 <application_name>"
    exit 1
fi
app="$1"

# Path to the address file
ADDRESS_FILE="src/$1/address.txt"

# Check if address file exists
if [ ! -f "$ADDRESS_FILE" ]; then
    echo "Error: address file '$ADDRESS_FILE' not found."
    exit 1
fi

# Read ADDRESS into an array
mapfile -t ADDRESS < "$ADDRESS_FILE"

# Ensure ADDRESS are loaded
if [ "${#ADDRESS[@]}" -lt 5 ]; then
    echo "Error: Not enough ADDRESS in '$ADDRESS_FILE'."
    exit 1
fi

# Bulk erase flash
sudo iceprog -b

# Generate binary file
cp src/"$app"/* .
gcc bin_gen.c
sudo ./a.out
rm weights_1.txt weights_2.txt weights_3.txt weights_4.txt samples.txt

# Write flash using loaded ADDRESS
sudo iceprog -o "${ADDRESS[0]}" -n to_flash/weights_1.bin # write weight mem 1
sudo iceprog -o "${ADDRESS[1]}" -n to_flash/weights_2.bin # write weight mem 2
sudo iceprog -o "${ADDRESS[2]}" -n to_flash/weights_3.bin # write weight mem 3
sudo iceprog -o "${ADDRESS[3]}" -n to_flash/weights_4.bin # write weight mem 4
sudo iceprog -o "${ADDRESS[4]}" -n to_flash/sample.bin    # write samples

# Read flash
rm from_flash/*
sudo iceprog -o "${ADDRESS[0]}" -R 8192 read.w1 # read weight mem 1
xxd read.w1 >> from_flash/read_1.txt # binary to hex conversion
sudo rm read.w1
sudo iceprog -o "${ADDRESS[1]}" -R 8192 read.w2 # read weight mem 2
xxd read.w2 >> from_flash/read_2.txt # binary to hex conversion
sudo rm read.w2
sudo iceprog -o "${ADDRESS[2]}" -R 8192 read.w3 # read weight mem 3
xxd read.w3 >> from_flash/read_3.txt # binary to hex conversion
sudo rm read.w3
sudo iceprog -o "${ADDRESS[3]}" -R 8192 read.w4 # read weight mem 4
xxd read.w4 >> from_flash/read_4.txt # binary to hex conversion
sudo rm read.w4
sudo iceprog -o "${ADDRESS[4]}" -R 32768 read.s # read samples
xxd read.s >> from_flash/read_s.txt # binary to hex conversion
sudo rm read.s

# Optional: Read entire flash
sudo iceprog -o "${ADDRESS[0]}" -R 65536 read.output # read whole flash
xxd read.output >> from_flash/read.txt # binary to hex conversion
sudo rm read.output

