#include "clock_generator.hpp"

ClockGenerator::~ClockGenerator()
{
    while (clocks) {
        clock *next = clocks->next;
        delete clocks;
        clocks = next;
    }
};

void ClockGenerator::add_clock(uint8_t &net, uint64_t period, uint64_t skew)
{
    if (skew >= period) throw "The skew value cannot exceed the period";

    clock *clk = new clock(net, period, skew);
    net = (clk->position < clk->period / 2) ? 0 : 1;

    if (clocks == NULL)
        clocks = clk;
    else {
        clock *last = clocks;
        while (last->next)
            last = last->next;
        last->next = clk;
    }
};

uint64_t ClockGenerator::next_event(void)
{
    uint64_t time_to_next = UINT64_MAX;
    clock *clk            = clocks;

    while (clk) {
        uint64_t ttn;

        if (clk->position < clk->period / 2)
            ttn = clk->period / 2 - clk->position;
        else
            ttn = clk->period - clk->position;

        if (time_to_next > ttn) time_to_next = ttn;

        clk = clk->next;
    }

    clk = clocks;
    while (clk) {
        uint8_t next_val;

        clk->position += time_to_next;
        if (clk->position >= clk->period) clk->position -= clk->period;

        next_val     = (clk->position < clk->period / 2) ? 0 : 1;
        clk->posedge = (next_val == 1 && clk->net == 0) ? true : false;
        clk->negedge = (next_val == 0 && clk->net == 1) ? true : false;
        clk->net = next_val;

        clk = clk->next;
    }

    return time_to_next;
};

bool ClockGenerator::is_posegde(uint8_t &net)
{
    clock *clk   = clocks;
    bool posedge = false;

    while (clk) {
        if (std::addressof(net) == std::addressof(clk->net)) {
            posedge = clk->posedge;
            break;
        }
        clk = clk->next;
    }

    return posedge;
};

bool ClockGenerator::is_negedge(uint8_t &net)
{
    clock *clk   = clocks;
    bool negedge = false;

    while (clk) {
        if (std::addressof(net) == std::addressof(clk->net)) {
            negedge = clk->negedge;
            break;
        }
        clk = clk->next;
    }

    return negedge;
};
