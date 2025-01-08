#include <stdio.h>

#include "weights_1.txt"
#include "weights_2.txt"
#include "weights_3.txt"
#include "weights_4.txt"
#include "samples.txt"

//signed char samples [] = {0,1};

int main(void)
{
    FILE *file, *file_2, *file_3;

    file = fopen("to_flash/weights_1.bin", "wb");
    fwrite(w1, sizeof(w1), 1, file);
    fclose(file);

    file = fopen("to_flash/weights_2.bin", "wb");
    fwrite(w2, sizeof(w2), 1, file);
    fclose(file);

    file = fopen("to_flash/weights_3.bin", "wb");
    fwrite(w3, sizeof(w3), 1, file);
    fclose(file);

    file = fopen("to_flash/weights_4.bin", "wb");
    fwrite(w4, sizeof(w4), 1, file);
    fclose(file);

	file = fopen("to_flash/sample.bin", "wb");
    fwrite(samples, sizeof(samples), 1, file);
    fclose(file);

    return 0;
}
