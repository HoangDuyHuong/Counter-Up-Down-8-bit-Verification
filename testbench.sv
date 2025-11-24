//==============
// Verification
//==============

// import package
import uvm_pkg::*;
`include "uvm_macros.svh"

//===============
//Interface
//===============
interface counter_if(input bit clk);
	logic rst_n;
  	logic pause;
  	logic mode;
  logic [7:0] data_out;
endinterface

//====================
//Class item_sequence
//====================
class counter_item extends uvm_sequence_item;
  `uvm_object_utils(counter_item)
  
//   Randomize input
  rand bit rst_n;
  rand bit mode;
  rand bit pause;
  
  bit [7:0]data_out;
  
  constraint c_dist {
    rst_n dist {0:/1, 1:/99};
    pause dist {1:/20, 0:/80};  
  }
  
  function new(string name = "counter_item");
    super.new(name);
  endfunction
  
  virtual function string convert2string();
    return $sformatf("rst_n: %0b  mode: %0b  pause: %0b  |data_out: %0d", rst_n, mode, pause, data_out);
  endfunction
endclass


//===================
//Class uvm_sequence
//===================
class counter_sequence extends uvm_sequence #(counter_item);
  `uvm_object_utils(counter_sequence)
  
  function new(string name = "counter_sequence");
    super.new(name);
  endfunction
  
  task body();
  	counter_item req;
    
    req = counter_item::type_id::create("req");
    start_item(req);
    req.rst_n = 0;
    req.mode  = 0;
    req.pause = 0;
    finish_item(req);
  
    repeat(10) begin
      start_item(req);
      if(!req.randomize())
        `uvm_error("[Sequence]","Randomize Failed");
    end
  endtask
endclass





//===================
//Class uvm_sequencer
//===================
class counter_sequencer extends uvm_sequencer #(counter_item);
  `uvm_component_utils(counter_sequencer)
  
  function new(string name = "counter_sequencer", uvm_component parent);
    super.new(name,parent);
  endfunction
  
endclass







//================
//Class uvm_driver
//================
class counter_driver extends uvm_driver #(counter_item);
  `uvm_component_utils(counter_driver)
  
  virtual counter_if vif;
  
  function new(string name = "counter_driver", uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if(!uvm_config_db #(virtual counter_if)::get(this,"","vif",vif))
      `uvm_fatal("[Driver]","No vif found from db")   
  endfunction
      
  task run_phase(uvm_phase phase);
  	
    vif.rst_n <= 0;
    vif.mode  <= 0;
    vif.pause <= 0;
    
    forever begin
      
      seq_item_port.get_next_item(req);
      
      @(posedge vif.clk);
    	vif.rst_n <= req.rst_n;
      	vif.mode  <= req.mode;
      	vif.pause <= req.pause;
      
      @(posedge vif.clk);
    		
      seq_item_port.item_done();
    end
    
  endtask   
endclass




//=================
//Class uvm_monitor
//=================
class counter_monitor extends uvm_monitor;
  `uvm_component_utils(counter_monitor)
  
  virtual counter_if vif;
  
  uvm_analysis_port #(counter_item) item_collected_port;
  
  counter_item trans_collected;
  
  function new(string name = "counter_monitor", uvm_component parent);
    super.new(name,parent);
    item_collected_port = new("item_collected_port", this);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if(!uvm_config_db #(virtual counter_if)::get(this,"","vif",vif))
      `uvm_fatal("[Monitor]","No vif found from db")
  endfunction
      
    task run_phase(uvm_phase phase);
    trans_collected = counter_item::type_id::create("trans_collected");
    
    forever begin
      @(posedge vif.clk);
      
      #1step;
      
      trans_collected.rst_n    <= vif.rst_n;
      trans_collected.mode     <= vif.mode;
      trans_collected.pause    <= vif.pause;
      trans_collected.data_out <= vif.data_out;
      
//       Sent to Scoreboard
      item_collected_port.write(trans_collected);
    end
    endtask
endclass


//===============
//Class uvm_agent
//===============
class counter_agent extends uvm_agent;
  `uvm_component_utils(counter_agent)
  
  counter_driver    driver;
  counter_monitor   monitor;
  counter_sequencer sequencer;
  
  function new(string name = "counter_agent", uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    monitor = counter_monitor::type_id::create("monitor",this);
    
    if(get_is_active() == UVM_ACTIVE) begin
      driver    = counter_driver::type_id::create("driver",this);
      sequencer = counter_sequencer::type_id::create("sequencer",this);
    end        
  endfunction
  
  function void connect_phase(uvm_phase phase);
    if(get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction
endclass


//====================
//Class uvm_scoreboard
//====================
class counter_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(counter_scoreboard)
  
  uvm_analysis_imp #(counter_item, counter_scoreboard) item_collected_export;
  
  bit[7:0] ref_count;
  
  function new(string name = "counter_scoreboard", uvm_component parent);
    super.new(name,parent);
    item_collected_export = new("item_collected_export", this);
    ref_count = 0;
  endfunction
  
  virtual function void write(counter_item trans);
  	
    if(!trans.rst_n) begin
    	ref_count = 0;
      `uvm_info(get_type_name(), "Reset...", UVM_HIGH)
    end
    else if(trans.pause) begin
    	ref_count = ref_count;
    end
    else begin
      if(trans.mode == 1) 
      	ref_count--;
      else 
        ref_count++;
    end
    
//     compare act_data and expect_data 
    if(trans.data_out !== ref_count) begin
      `uvm_error("[Scoreboard]", $sformatf("MISMATCH! mode = %0b, pause = %0b, | DUT_Out = %0d != REF_Out = %0d", trans.mode, trans.pause, trans.data_out, ref_count))
    end
    else begin
    	`uvm_info("[Scoreboard]", $sformatf("PASS! DUT = %0d | REF = %0d", trans.data_out,ref_count), UVM_HIGH)
    end
  endfunction
endclass
    
    
//===============
//Class uvm_env
//===============
class counter_env extends uvm_env;
  `uvm_component_utils(counter_env)
  
  counter_agent      agent;
  counter_scoreboard scb;
  
  function new(string name = "counter_env", uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    agent = counter_agent::type_id::create("agent", this);
    scb   = counter_scoreboard::type_id::create("scb", this);  
  endfunction
  
  function void connect_phase(uvm_phase phase);
    agent.monitor.item_collected_port.connect(scb.item_collected_export);
  endfunction
    
  
endclass

    
//===============
//Class base test
//===============
class counter_test extends uvm_test;
  `uvm_component_utils(counter_test)
  
  counter_env      env;
  counter_sequence seq;
  
  function new(string name = "counter_test", uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    env = counter_env::type_id::create("env", this);
    
  endfunction
  
  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    
    seq = counter_sequence::type_id::create("seq");
    
    `uvm_info("TEST","Sequence Start test ...", UVM_LOW)
    
    seq.start(env.agent.sequencer);
    #10ns;
    phase.drop_objection(this);
    
  endtask
  
endclass

    
    
//====================
//    TOP MODULE
//====================    
module testbench;
  bit clk;
  initial begin
  clk = 0;
    forever #5 clk = ~clk;
  end
  
  counter_if vif(clk);
  
  counter_UP_DOWN_8bit u_dut(
    .clk(vif.clk),
    .rst_n(vif.rst_n),
    .mode(vif.mode),
    .pause(vif.pause),
    .data_out(vif.data_out)
  );
  
  initial begin
    uvm_config_db #(virtual counter_if)::set(null, "*", "vif", vif);
    run_test("counter_test");
  end
endmodule
    
    
    
    
    
    
    
    
    
    
    
