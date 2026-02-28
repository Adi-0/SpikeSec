<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

Four LIF spiking neurons are arranged in a ring network to create a Physical Uncloneable Function (PUF) that produces a fingerprint unique to the specific chip being manufactured. Unlike ring oscillators that can normally be used for this, we use these four neurons for the job.

An 8-bit challenge sets each neuron's drive current (2 bits). The neurons interact over around 32 clock cycles: each one leaks, integrates drive, "excites" when the ring neighbor spikes, and then inhibits when the opposite neighbor spikes. The reset occurs when membrane potential reaches the threshold.

The special part about this is that its non-linear. By this, I mean since the threshold is 100 + trim, where trim (4-bit input) models per-chip process variation, small threshold shifts change which neurons fire and when. This creates our "uniqueness" for authentication.

## How to test

- Rest rst_n to low, then high.
- Set challenge on ui_in[7:0] and optional trim on uio_in[4:1]
- Assert start and wait 33 cycles for ui_out to return a logic high
- Check the response given by uo_out[7:0] (Then de-assert start in order to return to idle)

## External hardware

None needed