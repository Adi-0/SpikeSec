# SNN-based Physical Uncloneable Function

![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg)

## Overview

This project involves a hardware PUF built from four Leaky Integrate-and-Fire spiking neurons. We take advantage of spike-timing sensitivity to threshold variation as a source of "uniqueness" to use as a form of authentication.

To put it briefly, a PUF is a hardware primitive that stands for **Physical Uncloneable Function**, used for chip authentication, anti-counterfeiting, and cryptographic key generation. Traditional PUFs use ring oscillators or arbiter claims to create a sense of "uniqueness". Two chips running the same design will give different responses to the same 8 bit input (known as a challenge).

The key benefit our LIF-based PUF has over their traditional counterpart is that a simulated neuron's nonlinear properties (threshold, reset, recurrent feedback, etc.) are really noticeable and distinct when read as digital outputs.

## Network Architecture

Four LIF neurons are connected in a directed sing with cross-inhibition. Each neuron receives an drive current from the challenge input, excitation from its forward ring neighbor when that neighbor spikes, and inhibition from its opposite neighbor when it spikes. This creates a sort of competition where a neuron that fires early boosts its ring neightbor while suppressing the opposite.

Ultimate, the final spike pattern will depend on each of these four drives intaracted through feedback. The ring topology is deliberate, we make recurrent dependencies. A spike fron neuron 0 will affect neuron 1, afecting neuron 2, feeding back into neuron 0's inibitor. If we had a simpler feedforward arrangement, each neuron's output only would depend on its own input, creating a less complex and unique answer.

## Operation

To use the PUF, first set the rst_n pin to low for several cycles, then high. We set the 8 bit challenge on ui_in[7:0] and optionally the threshold trim on uin_in[4:1] (though the default of 0 is fine for basic testing). Assert uio_in[0] to start. The challenge and trim are latched on the next rising clk edge as the network runed for 32 cycles. At the point uio_out[0] (the done flag) gives a logic high, the response should be stable on uo_out[7;0]. At this point we de-assert uio_in[0] to set the system back to idle, before issuing another challenge.

The state machines has three states: IDLE, RUN, and DONE.


### Note
The following RTL is written in SystemVerilog, and follows the lowRISC coding convention when possible.
Two files are responsible for the project: 
- neuron_lif.v: The combinational LIF neuron module
- project.v: The top-level state machine that took 4 instances of neuron_lif

> This project was built on top of the TinyTapeout template, and was my submission for the open ended chip design project in ECE110 at the University of California, Santa Cruz. Thank you for checking this out!
