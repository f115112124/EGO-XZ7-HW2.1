/*
 * EGO-XZ7 HW2: ARM-controlled LED counter and AXI GPIO button interrupt.
 * Vivado/SDK 2018.3 hardware contract:
 *   hw2_gpio_ip_0 + 0x00000: eight active-high LED outputs.
 *   hw2_gpio_ip_0 + 0x10000: five active-high button inputs, IRQ enabled.
 *   hw2_gpio_ip_0/irq -> processing_system7_0/IRQ_F2P[0].
 *
 * A button press clears the counter and holds LEDs off for two seconds.
 * Counting then restarts at one, with one increment every 500 milliseconds.
 * The ISR only acknowledges the GPIO source and records an event. Debouncing,
 * UART output, timing and LED changes all run in main context.
 */

#include "xparameters.h"
#include "hw2_gpio.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xil_printf.h"
#include "xtime_l.h"
#include "sleep.h"
#include "xstatus.h"

#define GIC_DEVICE_ID       XPAR_SCUGIC_SINGLE_DEVICE_ID
#define LED_MASK            0xFFU
#define BUTTON_MASK         0x1FU
#define DEBOUNCE_MS         20U
#define COUNT_PERIOD_MS     500U
#define PAUSE_MS            2000U

static XScuGic Gic;

/* An aligned 32-bit sequence counter avoids a read/clear flag race. */
static volatile u32 ButtonIrqSequence;

static XTime ticks_for_ms(u32 milliseconds)
{
    return ((XTime)COUNTS_PER_SECOND * (XTime)milliseconds) / 1000U;
}

static XTime time_now(void)
{
    XTime now;
    XTime_GetTime(&now);
    return now;
}

static void buttons_isr(void *callback_reference)
{
    (void)callback_reference;
    if (hw2_irq_status() != 0U) {
        hw2_irq_clear();
        ++ButtonIrqSequence;
    }
}

static int initialize_gpio(void)
{
    hw2_gpio_initialize();
    return XST_SUCCESS;
}

static int initialize_interrupts(void)
{
    XScuGic_Config *configuration;
    int status;

    Xil_ExceptionInit();
    configuration = XScuGic_LookupConfig(GIC_DEVICE_ID);
    if (configuration == NULL) {
        xil_printf("ERROR: GIC configuration was not found.\r\n");
        return XST_FAILURE;
    }

    status = XScuGic_CfgInitialize(&Gic, configuration,
                                  configuration->CpuBaseAddress);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: GIC initialization failed (%d).\r\n", status);
        return status;
    }

    /* AXI GPIO holds ip2intc_irpt high until its pending status is cleared. */
    XScuGic_SetPriorityTriggerType(&Gic, BUTTON_INTERRUPT_ID, 0xA0U, 0x1U);
    status = XScuGic_Connect(&Gic, BUTTON_INTERRUPT_ID,
                            buttons_isr, NULL);
    if (status != XST_SUCCESS) {
        xil_printf("ERROR: connecting button ISR failed (%d).\r\n", status);
        return status;
    }

    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
        (Xil_ExceptionHandler)XScuGic_InterruptHandler, &Gic);
    XScuGic_Enable(&Gic, BUTTON_INTERRUPT_ID);
    hw2_irq_clear();
    hw2_irq_enable();
    Xil_ExceptionEnable();
    return XST_SUCCESS;
}

int main(void)
{
    u32 counter = 1U;
    u32 stable_buttons;
    u32 observed_sequence = 0U;
    int debounce_pending = 0;
    int paused = 0;
    XTime debounce_deadline = 0U;
    XTime pause_deadline = 0U;
    XTime next_count;

    xil_printf("\r\nEGO-XZ7 HW2: LED counter + packaged hw2_gpio_ip interrupt\r\n");
    if (initialize_gpio() != XST_SUCCESS) {
        return XST_FAILURE;
    }

    /* This standalone program owns CPU0; explicitly start the global timer. */
    XTime_SetTime(0U);
    stable_buttons = hw2_buttons_read() & BUTTON_MASK;
    if (initialize_interrupts() != XST_SUCCESS) {
        return XST_FAILURE;
    }
    next_count = time_now() + ticks_for_ms(COUNT_PERIOD_MS);
    xil_printf("IP base=0x%08x; LED=0x%08x; BUTTON=0x%08x; IRQ=%d.\r\n",
               (u32)HW2_GPIO_BASE, (u32)HW2_LED_BASE,
               (u32)HW2_BUTTON_BASE, BUTTON_INTERRUPT_ID);
    xil_printf("Ready: GPIO IRQ %d; LED=1; count every 500 ms.\r\n",
               BUTTON_INTERRUPT_ID);
    xil_printf("Press any button: clear LEDs, pause 2 s, restart from 1.\r\n");

    while (1) {
        XTime now = time_now();
        u32 current_sequence = ButtonIrqSequence;

        /* GPIO interrupts report both presses and releases, including bounce. */
        if (current_sequence != observed_sequence) {
            observed_sequence = current_sequence;
            debounce_deadline = now + ticks_for_ms(DEBOUNCE_MS);
            debounce_pending = 1;
        }

        if (debounce_pending && now >= debounce_deadline) {
            u32 current_buttons;
            u32 pressed;

            current_buttons = hw2_buttons_read()
                              & BUTTON_MASK;
            pressed = current_buttons & ~stable_buttons & BUTTON_MASK;
            stable_buttons = current_buttons;
            debounce_pending = 0;

            if (pressed != 0U) {
                counter = 0U;
                hw2_led_write(0U);
                paused = 1;
                pause_deadline = now + ticks_for_ms(PAUSE_MS);
                xil_printf("BUTTON=0x%02x: LED=0, pause 2 s (IRQ events %d).\r\n",
                           pressed, observed_sequence);
            }
        }

        if (paused) {
            if (now >= pause_deadline) {
                paused = 0;
                counter = 1U;
                hw2_led_write(counter);
                next_count = now + ticks_for_ms(COUNT_PERIOD_MS);
                xil_printf("Resume: LED=%d\r\n", counter);
            }
        } else if (now >= next_count) {
            counter = (counter + 1U) & LED_MASK;
            hw2_led_write(counter);
            next_count = now + ticks_for_ms(COUNT_PERIOD_MS);
            xil_printf("LED=%d\r\n", counter);
        }

        /* All waits occur outside the ISR; timer deadlines handle the pause. */
        usleep(1000U);
    }
}
