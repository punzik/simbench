#ifndef _IO_REG_H_
#define _IO_REG_H_

#define IO_REG_BASE 0x1000000

/* -- Register 'CTRL' -- */
#define IO_REG_CTRL (*(volatile uint32_t*)(IO_REG_BASE + 0x00000000))
#define IO_REG_CTRL_STOP (1 << 0)

/* -- Register 'DATA_ADDR' -- */
#define IO_REG_DATA_ADDR (*(volatile uint32_t*)(IO_REG_BASE + 0x00000004))
#define IO_REG_DATA_ADDR_ADDR__MASK 0xffffffff
#define IO_REG_DATA_ADDR_ADDR__SHIFT 0

/* -- Register 'DATA_LEN' -- */
#define IO_REG_DATA_LEN (*(volatile uint32_t*)(IO_REG_BASE + 0x00000008))
#define IO_REG_DATA_LEN_LEN__MASK 0xffffffff
#define IO_REG_DATA_LEN_LEN__SHIFT 0

/* -- Register 'MD5_OUT0' -- */
#define IO_REG_MD5_OUT0 (*(volatile uint32_t*)(IO_REG_BASE + 0x0000000c))
#define IO_REG_MD5_OUT0_DATA__MASK 0xffffffff
#define IO_REG_MD5_OUT0_DATA__SHIFT 0

/* -- Register 'MD5_OUT1' -- */
#define IO_REG_MD5_OUT1 (*(volatile uint32_t*)(IO_REG_BASE + 0x00000010))
#define IO_REG_MD5_OUT1_DATA__MASK 0xffffffff
#define IO_REG_MD5_OUT1_DATA__SHIFT 0

/* -- Register 'MD5_OUT2' -- */
#define IO_REG_MD5_OUT2 (*(volatile uint32_t*)(IO_REG_BASE + 0x00000014))
#define IO_REG_MD5_OUT2_DATA__MASK 0xffffffff
#define IO_REG_MD5_OUT2_DATA__SHIFT 0

/* -- Register 'MD5_OUT3' -- */
#define IO_REG_MD5_OUT3 (*(volatile uint32_t*)(IO_REG_BASE + 0x00000018))
#define IO_REG_MD5_OUT3_DATA__MASK 0xffffffff
#define IO_REG_MD5_OUT3_DATA__SHIFT 0

/* -- Register 'CONSOLE' -- */
#define IO_REG_CONSOLE (*(volatile uint32_t*)(IO_REG_BASE + 0x0000001c))
#define IO_REG_CONSOLE_DATA__MASK 0x000000ff
#define IO_REG_CONSOLE_DATA__SHIFT 0
#define IO_REG_CONSOLE_SEND (1 << 8)
#define IO_REG_CONSOLE_VALID (1 << 9)

#endif // _IO_REG_H_
