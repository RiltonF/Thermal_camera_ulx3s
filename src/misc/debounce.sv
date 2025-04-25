`default_nettype none
`timescale 1ns / 1ps

module debounce #(
  parameter int p_async_shift = 3,
  parameter int p_min_on = 1000
) (
  input  logic i_clk,
  input  logic i_trig,
  output logic o_trig
);



logic [p_async_shift-1:0] s_in_clocked = '0;
logic s_state = 1'b0; 
logic s_trig ;
logic unsigned [31:0] s_count;

  // Main process
  always_ff @(posedge i_clk) begin
    o_trig <= 1'b0;
    if(s_state != s_trig && s_count < (p_min_on - 1)) begin
      s_count <= s_count + 1;
    end
    else if(s_count >= (p_min_on - 1)) begin
      s_state <= s_trig;
      s_count <= 0;
      o_trig <= s_trig;
    end
    else begin
      s_count <= 0;
    end
  end

  // Clean input from external
  assign s_trig = s_in_clocked[p_async_shift-1];
  always_ff @(posedge i_clk) begin
    s_in_clocked <= {s_in_clocked[p_async_shift - 2:0],i_trig};
  end


endmodule
