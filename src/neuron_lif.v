//LIF Neuron to be used. Find next membrane 
module neuron_lif (
    input  wire [7:0] mem_cur,
    input  wire [7:0] drv,
    input  wire [7:0] threshold,
    input  wire       fwd_spike,
    input  wire       lat_spike,
    input  wire       did_spike,
    output wire [7:0] mem_next
);

  localparam logic [7:0] LEAK = 8'd3;
  localparam logic [7:0] EXCITE = 8'd16;
  localparam logic [7:0] INHIBIT = 8'd10;

  logic [8:0] after_leak;
  logic [8:0] after_drive;
  logic [8:0] after_excite;
  logic [8:0] after_inhibit;

  //Leak (floor at zero)
  assign after_leak = (mem_cur > LEAK) ? {1'b0, mem_cur} - {1'b0, LEAK}
                                       : 9'd0;

  //External drive
  assign after_drive = after_leak + {1'b0, drv};

  // Forward excitation
  assign after_excite = fwd_spike ? after_drive + {1'b0, EXCITE}
                                  : after_drive;

  // Lateral inhibition (floor at zero)
  assign after_inhibit = lat_spike ? ((after_excite > {1'b0, INHIBIT})
                                       ? after_excite - {1'b0, INHIBIT}
                                       : 9'd0)
                                   : after_excite;

  //Spike reset, else saturate 8 bits
  assign mem_next = did_spike ? 8'd0 :
                    after_inhibit[8] ? 8'd255 :
                                       after_inhibit[7:0];

endmodule