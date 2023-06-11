#include "uprintf.h"

#include <stdarg.h>
#include <stdint.h>

/*
 * ------------------- Простая замена printf ------------------------
 *
 * Спецификаторы в форматной строке так же как и в printf начинаются
 * со знака %. После этого знака может идти спецификатор типа с
 * опциональным указанием ширины выравнивания, символа для
 * выравнивания и направления выравнивания.
 *
 * Первым должен идти спецификатор символа выравнивания - знак '
 * (одинарная скобка). После него - символ для выравнивания.
 *
 * По умолчанию числа выравниваются символом '0' по правому краю, а
 * строки пробелом по левому краю.
 *
 * Далее идет указатель ширины - десятичное число со знаком,
 * обозначающее минимальную длину выводимой строки. Если строка
 * получается меньше этого числа, недостающая длина добирается
 * символами выравнивания. Если ширина указана в виде отрицательного
 * числа, то выравнивание выполняется по правому краю. Если для числа
 * не указан символ выравнивания, то оно всегда выравнивается символом
 * '0' по правому краю. Вместо числа может стоять символ '*',
 * говоряший о том, что ширину нужно брать из аргумента функции.
 *
 * Спецификатор типа может иметь префикс 'l', обозначающий длинное целое
 * (64 бита) и/или префикс 'u', обозначающий беззнаковое число.
 *
 * Спецификаторы типа:
 *   d, i      Десятичное целое.
 *   o         Восьмиричное целое.
 *   b         Двоичное целое.
 *   x         Шестнадцатиричное целое (строчными).
 *   X         Шестнадцатиричное целое (прописные).
 *   c         Символ.
 *   s         Строка. Если указана ширина, то выравнивание по левому краю.
 *
 * Пример:
 *   p("I:+%'=-6i+\n", 10);
 *   Вывод: I:+====10+
 *
 */

static const char abet[2][16] = {{'0', '1', '2', '3', '4', '5', '6', '7', '8',
                                  '9', 'A', 'B', 'C', 'D', 'E', 'F'},
                                 {'0', '1', '2', '3', '4', '5', '6', '7', '8',
                                  '9', 'a', 'b', 'c', 'd', 'e', 'f'}};

typedef enum {
    PS_REGULAR = 0,
    PS_JSYM_SPEC,
    PS_JSYM,
    PS_WIDTH_SIGN,
    PS_WIDTH_ARG,
    PS_WIDTH,
    PS_TYPE,
} pstate;

static int l_strlen(const char *str)
{
    int l = 0;
    while (*str++)
        l++;
    return l;
}

/* Helper functions for p() */
static void print_string(put_char_func pc, const char *str, int width,
                         char wchr)
{
    int sl, w;

    if (width < 0) {
        sl = l_strlen(str);
        for (w = -width; w > sl; w--)
            pc(wchr);
    }

    for (sl = 0; *str; str++, sl++)
        pc(*str);

    if (width > 0) {
        for (w = width; w > sl; w--)
            pc(wchr);
    }
}

/*
static void div(uint32_t n, uint32_t d, uint32_t *q, uint32_t *r)
{
    uint32_t _q = 0;
    uint32_t _r = 0;
    uint32_t b  = 0x80000000L;

    if (d == 0) return;

    while (b) {
        _r <<= 1;
        _r |= (n & b) ? 1 : 0;

        if (_r >= d) {
            _r -= d;
            _q |= b;
        }

        b >>= 1;
    }

    *q = _q;
    *r = _r;
}
*/

static void print_decimal(put_char_func pc, uint32_t u, int negative,
                          unsigned int base, int width, int lcase, char wchr)
{
    if (base > 16) base = 16;
    if (base < 2) base = 2;
    if (lcase != 0) lcase = 1;

    char s[66];
    int si = 64;
    uint32_t l;

    s[si--] = 0;

    do {
        // div(u, base, &u, &l);
        l = u % base;
        u = u / base;
        s[si--] = abet[lcase][l];
    } while (u > 0);

    if (negative) {
        if (wchr == '0') {
            pc('-');

            if (width > 0)
                width--;
            else if (width < 0)
                width++;
        }
        else
            s[si--] = '-';
    }

    si++;

    print_string(pc, s + si, width, wchr);
}

static void print_unsigned(put_char_func pc, uint32_t s, unsigned int base,
                           int width, int lcase, char wchr)
{
    print_decimal(pc, s, 0, base, width, lcase, wchr);
}

static void print_signed(put_char_func pc, int64_t s, unsigned int base,
                         int width, int lcase, char wchr)
{
    if (s < 0)
        print_decimal(pc, (uint32_t)-s, 1, base, width, lcase, wchr);
    else
        print_decimal(pc, (uint32_t)s, 0, base, width, lcase, wchr);
}

static int l_isdigit(char c)
{
    return (c >= '0' && c <= '9') ? 1 : 0;
}

/* Like a vprintf */
void pv(put_char_func pc, const char *fmt, va_list ap)
{
    /* Initialization for supress gcc warnings */
    int width = 0, wsign = 1, lng = 0, sgn = 0, ab = 0;

    /* Width adjustment character */
    char wchr = 0;

    unsigned int base = 0;
    char c;
    int64_t d;

    pstate st = PS_REGULAR;

    for (;;) {
        c = *fmt;

        if (c == 0) break;

        switch (st) {
            /* ---------------------------------------------------------- */
        case PS_REGULAR:
            fmt++;

            if (c == '%') {
                st    = PS_JSYM_SPEC;
                lng   = 0;
                sgn   = 1;
                width = 0;
                wsign = 1;
                base  = 10;
                ab    = 0;
                wchr  = 0;
            }
            else
                pc(c);

            break;

            /* ---------------------------------------------------------- */
        case PS_JSYM_SPEC:
            if (c == '\'') {
                fmt++;
                st = PS_JSYM;
            }
            else
                st = PS_WIDTH_SIGN;
            break;

            /* ---------------------------------------------------------- */
        case PS_JSYM:
            fmt++;
            wchr = c;

            st = PS_WIDTH_SIGN;
            break;

            /* ---------------------------------------------------------- */
        case PS_WIDTH_SIGN:
            if (c == '-') {
                fmt++;
                wsign = -1;
            }

            st = PS_WIDTH_ARG;
            break;

            /* ---------------------------------------------------------- */
        case PS_WIDTH_ARG:
            if (c == '*') {
                fmt++;
                width = va_arg(ap, int);
                st    = PS_TYPE;
            }
            else
                st = PS_WIDTH;
            break;

            /* ---------------------------------------------------------- */
        case PS_WIDTH:
            if (l_isdigit(c)) {
                fmt++;
                width = width * 10 + (c - '0');
            }
            else
                st = PS_TYPE;
            break;

            /* ---------------------------------------------------------- */
        case PS_TYPE:
            fmt++;

            switch (c) {
            case 'l':
                lng = 1;
                continue;

            case 'u':
                sgn = 0;
                continue;

            case 'd':
            case 'i':
            case 'b':
            case 'o':
            case 'x':
            case 'X':
                if ((lng) && (sgn))
                    d = (int64_t)va_arg(ap, long long);
                else if ((lng) && (!sgn))
                    d = (int64_t)va_arg(ap, unsigned long long);
                else if ((!lng) && (sgn))
                    d = (int64_t)va_arg(ap, int);
                else
                    d = (int64_t)va_arg(ap, unsigned int);

                ab = 0;

                switch (c) {
                case 'd':
                case 'i':
                    base = 10;
                    break;
                case 'b':
                    base = 2;
                    break;
                case 'o':
                    base = 8;
                    break;
                case 'x':
                    ab = 1;
                case 'X':
                    base = 16;
                    break;
                default:
                    break;
                }

                if (!wchr) {
                    wchr  = '0';
                    wsign = -1;
                }

                if (sgn)
                    print_signed(pc, d, base, (wsign > 0) ? width : -width, ab,
                                 wchr);
                else
                    print_unsigned(pc, (uint32_t)d, base,
                                   (wsign > 0) ? width : -width, ab, wchr);
                break;

            case 'c':
                pc((char)va_arg(ap, int));
                break;

            case 's':
                if (!wchr) wchr = ' ';
                print_string(pc, va_arg(ap, char *),
                             (wsign > 0) ? width : -width, wchr);
                break;

            case '%':
                pc('%');
                break;

            default:
                pc('%');
                pc(c);
            }

            st = PS_REGULAR;
            break;

            /* ---------------------------------------------------------- */
        default:
            st = PS_REGULAR;
        }
    }
}

/* Universal printf */
void pp(put_char_func pc, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    pv(pc, fmt, ap);
    va_end(ap);
}

/* Print to console */
void p(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    pv(put_char, fmt, ap);
    va_end(ap);
}

/* Print to string */
int psn(char *str, int size, const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);

    int n = 0;

    /* Nested function. GCC specific */
    void put_char_str(char c)
    {
        if (n < size) {
            *str++ = c;
            n++;
        }
    }

    pv(put_char_str, fmt, ap);

    va_end(ap);

    return n;
}
