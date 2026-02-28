/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 *
 * SNN Based Physical Unclonable Function (PUF)
 *
 * Aditya Kumar.
 */

`default_nettype none

/*
module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 0;
  assign uio_oe  = 0;

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, clk, rst_n, 1'b0};

endmodule
*/

module tt_um_neuro_puf (
    input  wire [7:0] ui_in,// challenge
    output wire [7:0] uo_out, // response
    input  wire [7:0] uio_in, // [0] start, [4:1] threshold trim
    output wire [7:0] uio_out, //done flag
    output wire [7:0] uio_oe, // io direction
    input  wire       ena, // classic enable pin
    input  wire       clk,
    input  wire       rst_n
);

//bidirectional pin
  assign uio_oe = 8'b0000_0001;
  assign uio_out[7:1] = 7'd0;

  localparam [7:0] THRESH_BASE = 8'd100;
  localparam [4:0] LAST_CYCLE = 5'd31;

  //state machine
  typedef enum logic [1:0] {
      S_IDLE = 2'd0,
      S_RUN  = 2'd1,
      S_DONE = 2'd2
  } state_t;

  //map inputs
  logic start;
  logic [3:0] trim;
  logic [7:0] threshold;

  assign start = uio_in[0];
  assign trim = uio_in[4:1];
  assign threshold = THRESH_BASE + {4'd0, trim};

  //registers _q and next state _d
  state_t     state_q,      state_d;
  logic [4:0] cycle_q,      cycle_d;
  logic [7:0] challenge_q,  challenge_d;
  logic [7:0] mem0_q,       mem0_d;
  logic [7:0] mem1_q,       mem1_d;
  logic [7:0] mem2_q,       mem2_d;
  logic [7:0] mem3_q,       mem3_d;
  logic [3:0] spike_map_q,  spike_map_d;
  logic [3:0] first_time_q, first_time_d;
  logic       time_valid_q, time_valid_d;

  //spike detection
  logic [3:0] spiked;
  assign spiked[0] = (mem0_q >= threshold);
  assign spiked[1] = (mem1_q >= threshold);
  assign spiked[2] = (mem2_q >= threshold);
  assign spiked[3] = (mem3_q >= threshold);

  // drive currents
  logic [7:0] drive0, drive1, drive2, drive3;
  assign drive0 = {4'd0, challenge_q[1:0], 2'b00};
  assign drive1 = {4'd0, challenge_q[3:2], 2'b00};
  assign drive2 = {4'd0, challenge_q[5:4], 2'b00};
  assign drive3 = {4'd0, challenge_q[7:6], 2'b00};

  //neuron instances
  logic [7:0] mem0_next, mem1_next, mem2_next, mem3_next;
  neuron_lif u_n0 (
    .mem_cur   (mem0_q),
    .drv       (drive0),
    .threshold (threshold),
    .fwd_spike (spiked[3]),
    .lat_spike (spiked[2]),
    .did_spike (spiked[0]),
    .mem_next  (mem0_next)
  );

  neuron_lif u_n1 (
    .mem_cur   (mem1_q),
    .drv       (drive1),
    .threshold (threshold),
    .fwd_spike (spiked[0]),
    .lat_spike (spiked[3]),
    .did_spike (spiked[1]),
    .mem_next  (mem1_next)
  );

  neuron_lif u_n2 (
    .mem_cur   (mem2_q),
    .drv       (drive2),
    .threshold (threshold),
    .fwd_spike (spiked[1]),
    .lat_spike (spiked[0]),
    .did_spike (spiked[2]),
    .mem_next  (mem2_next)
  );

  neuron_lif u_n3 (
    .mem_cur   (mem3_q),
    .drv       (drive3),
    .threshold (threshold),
    .fwd_spike (spiked[2]),
    .lat_spike (spiked[1]),
    .did_spike (spiked[3]),
    .mem_next  (mem3_next)
  );
  
  assign uo_out = {first_time_q, spike_map_q};
  assign uio_out[0] = (state_q == S_DONE);

  always_comb begin
    state_d = state_q;
    cycle_d = cycle_q;
    challenge_d = challenge_q;
    mem0_d = mem0_q;
    mem1_d = mem1_q;
    mem2_d = mem2_q;
    mem3_d = mem3_q;
    spike_map_d = spike_map_q;
    first_time_d = first_time_q;
    time_valid_d = time_valid_q;

    case (state_q)
      S_IDLE: begin
        if (start) begin
          state_d = S_RUN;
          cycle_d = 5'd0;
          challenge_d = ui_in;
          mem0_d = 8'd0;
          mem1_d = 8'd0;
          mem2_d = 8'd0;
          mem3_d = 8'd0;
          spike_map_d = 4'd0;
          first_time_d = 4'd0;
          time_valid_d = 1'b0;
        end
      end

      S_RUN: begin
        mem0_d = mem0_next;
        mem1_d = mem1_next;
        mem2_d = mem2_next;
        mem3_d = mem3_next;

        spike_map_d = spike_map_q | spiked;

        if (!time_valid_q && (spiked != 4'd0)) begin
          first_time_d = cycle_q[4:1];
          time_valid_d = 1'b1;
        end

        if (cycle_q == LAST_CYCLE)
          state_d = S_DONE;
        else
          cycle_d = cycle_q + 5'd1;
      end

      S_DONE: begin
        if (!start)
          state_d = S_IDLE;
      end

      default: state_d = S_IDLE;
    endcase
  end

 always_ff @(posedge clk) begin
    if (!rst_n) begin
      state_q      <= S_IDLE;
      cycle_q      <= 5'd0;
      challenge_q  <= 8'd0;
      mem0_q       <= 8'd0;
      mem1_q       <= 8'd0;
      mem2_q       <= 8'd0;
      mem3_q       <= 8'd0;
      spike_map_q  <= 4'd0;
      first_time_q <= 4'd0;
      time_valid_q <= 1'b0;
    end else begin
      state_q      <= state_d;
      cycle_q      <= cycle_d;
      challenge_q  <= challenge_d;
      mem0_q       <= mem0_d;
      mem1_q       <= mem1_d;
      mem2_q       <= mem2_d;
      mem3_q       <= mem3_d;
      spike_map_q  <= spike_map_d;
      first_time_q <= first_time_d;
      time_valid_q <= time_valid_d;
    end
  end

endmodule