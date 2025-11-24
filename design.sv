//======================
// 8 bit Counter UP DOWN
//======================

//===========
// Design DUT
//===========

module counter_UP_DOWN_8bit (
  input clk,
  input rst_n,
  input mode,
  input pause,
  output reg [7:0] data_out

);
	
  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
    	data_out <= 8'h00;
    end
    
    else if(pause) begin
    	data_out <= data_out;
    end
      
    else begin
      if(mode == 1) begin
      	data_out <= data_out - 1;
      end
      else begin
      	data_out = data_out + 1;
      end
    end
  end
endmodule

