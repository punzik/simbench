#include "../io_reg.h"
#include "uprintf.h"

#include <stdint.h>

void put_char(char c)
{
    IO_REG_CONSOLE = c | IO_REG_CONSOLE_SEND;
}

#define N       200
#define CHUNK   4
#define ARR_LEN (10 * N / 3 + 1)

static int arr[ARR_LEN];

void print_digit(int d)
{
    static int cnt = 0;

    p("%d", d);
    cnt++;

    if (cnt == CHUNK) {
        p("\n");
        cnt = 0;
    }
}

/* See: https://en.wikipedia.org/wiki/Spigot_algorithm */

int main()
{
    p("\nComputation of %d first digits of PI\n", N);

    for (int i = 0; i < ARR_LEN; i++)
        arr[i] = 2;

    int nines    = 0;
    int predigit = 0;

    for (int j = 1; j < N + 1; j++) {
        int q = 0;

        for (int i = ARR_LEN; i > 0; i--) {
            int x      = 10 * arr[i - 1] + q * i;
            arr[i - 1] = x % (2 * i - 1);
            q          = x / (2 * i - 1);
        }

        arr[0] = q % 10;
        q      = q / 10;

        if (9 == q)
            nines++;
        else if (10 == q) {
            print_digit(predigit + 1);

            for (int k = 0; k < nines; k++)
                print_digit(0);

            predigit = 0;
            nines    = 0;
        }
        else {
            print_digit(predigit);
            predigit = q;

            if (0 != nines) {
                for (int k = 0; k < nines; k++)
                    print_digit(9);

                nines = 0;
            }
        }
    }
    p("%d", predigit);

    p("\nDONE\n");

    /* Stop simulation */
    IO_REG_CTRL = IO_REG_CTRL_STOP;

    for (;;) {
    };
}
