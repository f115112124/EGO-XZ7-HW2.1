/* Register access for the packaged hw2_gpio_ip 1.0 subsystem.
 * Two standard AXI GPIO blocks are packaged behind one AXI slave interface.
 * LED bank offset 0, button bank offset 0x10000. GPIO IRQ status is TOW.
 */
#ifndef HW2_GPIO_H
#define HW2_GPIO_H
#include "xparameters.h"
#include "xil_io.h"
#include "xil_types.h"

#if defined(XPAR_HW2_GPIO_IP_0_S_AXI_BASEADDR)
#define HW2_GPIO_BASE XPAR_HW2_GPIO_IP_0_S_AXI_BASEADDR
#elif defined(XPAR_HW2_GPIO_IP_0_BASEADDR)
#define HW2_GPIO_BASE XPAR_HW2_GPIO_IP_0_BASEADDR
#else
#error "The exported hardware must contain hw2_gpio_ip_0 with an AXI memory map."
#endif

#ifndef XPAR_FABRIC_HW2_GPIO_IP_0_IRQ_INTR
#error "Connect hw2_gpio_ip_0/irq to PS IRQ_F2P[0] and export the hardware again."
#endif
#define BUTTON_INTERRUPT_ID XPAR_FABRIC_HW2_GPIO_IP_0_IRQ_INTR
#define HW2_LED_BASE ((UINTPTR)HW2_GPIO_BASE)
#define HW2_BUTTON_BASE ((UINTPTR)HW2_GPIO_BASE + 0x10000U)
#define HW2_GPIO_DATA 0x000U
#define HW2_GPIO_TRI  0x004U
#define HW2_GPIO_GIER 0x11CU
#define HW2_GPIO_ISR  0x120U
#define HW2_GPIO_IER  0x128U
#define HW2_GPIO_CHANNEL_IRQ 1U

static void hw2_led_write(u32 value)
{
    Xil_Out32(HW2_LED_BASE + HW2_GPIO_DATA, value & 0xFFU);
}
static u32 hw2_buttons_read(void)
{
    return Xil_In32(HW2_BUTTON_BASE + HW2_GPIO_DATA) & 0x1FU;
}
static u32 hw2_irq_status(void)
{
    return Xil_In32(HW2_BUTTON_BASE + HW2_GPIO_ISR) & HW2_GPIO_CHANNEL_IRQ;
}
static void hw2_irq_clear(void)
{
    u32 pending = hw2_irq_status();
    /* Toggle-on-write: write only bits currently pending. */
    if (pending != 0U) Xil_Out32(HW2_BUTTON_BASE + HW2_GPIO_ISR, pending);
}
static void hw2_irq_disable(void)
{
    Xil_Out32(HW2_BUTTON_BASE + HW2_GPIO_GIER, 0U);
    Xil_Out32(HW2_BUTTON_BASE + HW2_GPIO_IER, 0U);
}
static void hw2_irq_enable(void)
{
    Xil_Out32(HW2_BUTTON_BASE + HW2_GPIO_IER, HW2_GPIO_CHANNEL_IRQ);
    Xil_Out32(HW2_BUTTON_BASE + HW2_GPIO_GIER, 0x80000000U);
}
static void hw2_gpio_initialize(void)
{
    Xil_Out32(HW2_LED_BASE + HW2_GPIO_TRI, 0U);
    hw2_led_write(1U);
    Xil_Out32(HW2_BUTTON_BASE + HW2_GPIO_TRI, 0x1FU);
    hw2_irq_disable();
    hw2_irq_clear();
}
#endif
