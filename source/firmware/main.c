#include "../io_reg.h"
#include "md5.h"
#include "uprintf.h"

#include <stdint.h>

#define DATA_ADDR 0x10000
#define DATA_LEN  0x10000

void put_char(char c)
{
    IO_REG_CONSOLE = c | IO_REG_CONSOLE_SEND;
}

int main(void)
{
    uint8_t result[16];

    md5Buf((uint8_t *)DATA_ADDR, DATA_LEN, result);

    IO_REG_MD5_OUT0 = *(uint32_t *)(result + 0);
    IO_REG_MD5_OUT1 = *(uint32_t *)(result + 4);
    IO_REG_MD5_OUT2 = *(uint32_t *)(result + 8);
    IO_REG_MD5_OUT3 = *(uint32_t *)(result + 12);

    /* Stop simulation */
    IO_REG_CTRL = IO_REG_CTRL_STOP;

    for (;;) {
    };
}
