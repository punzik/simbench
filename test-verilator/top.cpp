#include "Vtestbench.h"
#include "clock_generator.hpp"

#include <cstdint>
#include <verilated.h>
#include <verilated_vcd_c.h>

#define DUMPFILE "testbench.vcd"

int main(int argc, char **argv)
{
    VerilatedContext *ctx = new VerilatedContext;
    ctx->commandArgs(argc, argv);

    /* Create model instance */
    Vtestbench *top = new Vtestbench(ctx);

#if (VM_TRACE == 1)
    VerilatedVcdC *vcd = new VerilatedVcdC;
    ctx->traceEverOn(true);
    top->trace(vcd, 99);
    vcd->open(DUMPFILE);
#endif

    /* Create clock source */
    ClockGenerator *clk = new ClockGenerator;

    /* Add clocks and go to first event */
    clk->add_clock(top->clock, 10000, 0);
    clk->next_event();

    /* Cycle counter */
    uint64_t cycle = 0;

    /* ---- Evaluation loop ---- */
    while (!ctx->gotFinish()) {
        /* Clock event */
        ctx->timeInc(clk->next_event());

        /* Get output values (before clock edge) */
        if (clk->is_posegde(top->clock)) {
            // NOP
        }

        /* Eval */
        top->eval();

        /* Put input values (after clock edge)*/
        if (clk->is_posegde(top->clock)) {
            // NOP
        }

        /* Trace steady-state values */
#if (VM_TRACE == 1)
        if (vcd) vcd->dump(ctx->time());
#endif

        cycle ++;
    }

    top->final();
    printf("[%lu] Stop simulation\n", ctx->time());

#if (VM_TRACE == 1)
    if (vcd) {
        vcd->close();
        delete vcd;
    }
#endif

    delete top;
    delete ctx;
    return 0;
}
