#ifndef _CLOCK_GENERATOR_HPP
#define _CLOCK_GENERATOR_HPP

#include <cstdint>
#include <memory>

class ClockGenerator
{
protected:
    struct clock {
        clock(uint8_t &net, uint64_t period, uint64_t position) :
            net(net), period(period), position(position), next(NULL),
            posedge(false), negedge(false) {};

        uint8_t &net;
        uint64_t period;
        uint64_t position;
        bool posedge;
        bool negedge;
        clock *next;
    } *clocks = NULL;

public:
    ~ClockGenerator();
    void add_clock(uint8_t &net, uint64_t period, uint64_t skew);
    uint64_t next_event(void);
    bool is_posegde(uint8_t &net);
    bool is_negedge(uint8_t &net);
};

#endif // _CLOCK_GENERATOR_HPP
