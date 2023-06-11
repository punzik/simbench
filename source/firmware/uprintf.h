#ifndef _UPRINTF
#define _UPRINTF
#include <stdint.h>
#include <stdarg.h>

typedef void (*put_char_func)(char c);
extern void put_char(char c);

void pv(put_char_func pc, const char *fmt, va_list ap);
void pp(put_char_func pc, const char *fmt, ...);

void p(const char *fmt, ...);
int psn(char *str, int size, const char *fmt, ...);

#endif /* _UPRINTF */
