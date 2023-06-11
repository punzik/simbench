#ifndef _IO_REG_H_
#define _IO_REG_H_

#define IO_REG_BASE 0x1000000

/* -- Register 'CTRL' -- */
#define IO_REG_CTRL (*(volatile uint32_t*)(IO_REG_BASE + 0x00000000))
#define IO_REG_CTRL_STOP (1 << 0)

/* -- Register 'CONSOLE' -- */
#define IO_REG_CONSOLE (*(volatile uint32_t*)(IO_REG_BASE + 0x00000004))
#define IO_REG_CONSOLE_DATA__MASK 0x000000ff
#define IO_REG_CONSOLE_DATA__SHIFT 0
#define IO_REG_CONSOLE_SEND (1 << 8)
#define IO_REG_CONSOLE_VALID (1 << 9)

#endif // _IO_REG_H_
