 `include "VX_define.vh" 


module DE_STAGE(
  input clk,
  input reset,
  input [`FE_latch_WIDTH-1:0] from_FE_latch,
  input [`from_AGEX_to_DE_WIDTH-1:0] from_AGEX_to_DE,  
  input [`from_MEM_to_DE_WIDTH-1:0] from_MEM_to_DE,     
  input [`from_WB_to_DE_WIDTH-1:0] from_WB_to_DE,  
  output [`from_DE_to_FE_WIDTH-1:0] from_DE_to_FE,   
  output[`DE_latch_WIDTH-1:0] DE_latch_out
  //output [15:0] from_DE_to_MEM //equal to num registers
);

/* pipeline latch*/ 
 reg [`DE_latch_WIDTH-1:0] DE_latch;

  /* register file */ 
  reg [`DBITS-1:0] regs [`REGWORDS-1:0];
  /* busy bit table */
  reg [`DBITS-1:0] bb_table;  
 /* decode signals */
  
  wire [`INSTBITS-1:0] inst_DE; 
  wire [`INSTBITS-1:0] inst_logic;
  wire clear_bubble_reg;
  wire [`DBITS-1:0] PC_DE;
  wire [`DBITS-1:0] pcplus_DE; 
  wire [`OP1BITS-1:0] op1_DE;
  wire [`OP2BITS-1:0] op2_DE;
  wire [`IMMBITS-1:0] imm_DE;
  wire [`REGNOBITS-1:0] rd_DE;
  wire [`REGNOBITS-1:0] rs_DE;
  wire [`REGNOBITS-1:0] rt_DE;
  
  wire signed [`DBITS-1:0] regval1_DE;
  wire signed [`DBITS-1:0] regval2_DE;
  wire signed [`DBITS-1:0] sxt_imm_DE;


  wire is_br_DE;
  wire is_jmp_DE;
  wire writes_rt;
  wire rd_mem_DE;
  wire wr_mem_DE;
  wire wr_reg_DE;
  wire [`REGNOBITS-1:0] wregno_DE;
  
  // experimental added signals
  reg [`DBITS-1:0] prev_inst;
  reg should_bubble;
  
  wire[`DE_latch_WIDTH-1:0] DE_latch_contents; 
  wire[`BUS_CANARY_WIDTH-1:0] bus_canary_DE; 
 // **TODO: Complete the rest of the pipeline 
 
  //from WB wires
  wire from_WB_write;
  wire from_WB_readmem;
  wire [`REGNOBITS-1:0] from_WB_regno;
  wire [`DBITS-1:0] from_WB_memval;
  wire [`DBITS-1:0] from_WB_aluval;
  
  //from AGEX:
  wire from_AGEX_is_br;
  wire from_AGEX_is_jmp;
  wire from_AGEX_br_cond;
  wire [`DBITS-1:0] from_AGEX_br_target;
  wire [`DBITS-1:0] from_AGEX_jmp_target;
// extracting a part of opcode 
  
  assign op1_DE = inst_DE[31:26];  // example code 

 // complete the rest of instruction decoding 
  assign op2_DE = inst_DE[25:18];
  assign imm_DE = inst_DE[23:8];
  assign rd_DE = inst_DE[11:8];
  assign rs_DE = inst_DE[7:4];
  assign rt_DE = inst_DE[3:0];
  
  assign regval1_DE = regs[rs_DE];
  assign regval2_DE = regs[rt_DE];
  assign writes_rt = ((op1_DE == 6'b010010) || (inst_DE[31] == 1'b1));
  
  assign is_br_DE = (inst_DE[31:28] == 4'b0010);
  assign is_jmp_DE = (inst_DE[31:28] == 4'b0011);
  assign rd_mem_DE = (op1_DE == 6'b010010); // only load instruction
  assign wr_reg_DE = (writes_rt || (op1_DE == 6'b000000));
  assign wr_mem_DE = (op1_DE == 6'b011010); // only store instruction
  assign wregno_DE = (writes_rt) ? rt_DE : rd_DE;
  
 
// assign wire to send the contents of DE latch to other pipeline stages  
  assign DE_latch_out = DE_latch; 
  
    // Sign extension example 
  SXT mysxt (.IN(imm_DE), .OUT(sxt_imm_DE));
  


// decoding the contents of FE latch out. the order should be matched with the fe_stage.v 
  assign {
            inst_logic, // inst_logic is instruction from fetch, inst_DE is instruction in decode
            PC_DE, 
            pcplus_DE,
            bus_canary_DE 
            }  = from_FE_latch;  // based on the contents of the latch, you can decode the content 
            
   //from WB signals:
  assign {
    from_WB_write, //1 bit
    from_WB_readmem, // 1 bit
    from_WB_regno, //REGNOBITS
    from_WB_memval, //DBITS
    from_WB_aluval  //DBITS
  } = from_WB_to_DE;

  assign {
    from_AGEX_is_br,
    from_AGEX_is_jmp,
    from_AGEX_br_cond,
    from_AGEX_br_target,
    from_AGEX_jmp_target
  } = from_AGEX_to_DE;
  


  //assign clear_bubble_reg = (from_AGEX_is_jmp || from_AGEX_is_br);
  assign inst_DE = (should_bubble) ? 0 : inst_logic; // inst_DE = 0 should make other values in DE_latch = 0 as well
    
    //assign from_DE_to_MEM = {
       // bb_table
    //};

    assign DE_latch_contents = {
                                  inst_DE,
                                  PC_DE,
                                  pcplus_DE,
                                  op1_DE,
                                  op2_DE,
                                  regval1_DE,
                                  regval2_DE,
                                  sxt_imm_DE,
                                  is_br_DE,
                                  is_jmp_DE,
                                  rd_mem_DE,
                                  wr_mem_DE,
                                  wr_reg_DE,
                                  wregno_DE,

                                  // more signals might need
                                   bus_canary_DE 
                                  }; 
    
  always @ (negedge clk or posedge reset) begin
    if(reset) begin
	  	regs[0] <= {`DBITS{1'b0}};
	  	regs[1] <= {`DBITS{1'b0}};
	   	regs[2] <= {`DBITS{1'b0}};
		  regs[3] <= {`DBITS{1'b0}};
	  	regs[4] <= {`DBITS{1'b0}};
		  regs[5] <= {`DBITS{1'b0}};
		  regs[6] <= {`DBITS{1'b0}};
		  regs[7] <= {`DBITS{1'b0}};
		  regs[8] <= {`DBITS{1'b0}};
		  regs[9] <= {`DBITS{1'b0}};
		  regs[10] <= {`DBITS{1'b0}};
		  regs[11] <= {`DBITS{1'b0}};
		  regs[12] <= {`DBITS{1'b0}};
		  regs[13] <= {`DBITS{1'b0}};
		  regs[14] <= {`DBITS{1'b0}};
		  regs[15] <= {`DBITS{1'b0}}; 
     end else begin
        if (from_WB_write) begin
            regs[from_WB_regno] <= (from_WB_readmem) ? from_WB_memval : from_WB_aluval;
            bb_table[from_WB_regno] = 0; // set the dest num in bb to 0 here (on neg edge)
        end
        if (wr_reg_DE)                        // set busy bits to 1 on this edge too.                         
            bb_table[wregno_DE] = 1;            //if write to x comes in right as one finishes, set x to busy
     end
  end

  always @ (posedge clk or posedge reset) begin
    if(reset) begin
      DE_latch <= {`DE_latch_WIDTH{1'b0}};
      // might need more code 
      end
     else begin
     // need to complete. e.g.) stall? 
      DE_latch <= DE_latch_contents;
      //should_bubble <= (inst_logic[31:29] == 3'b001) && !clear_bubble_reg;
      // if not bubbling, bubble if branch instruction in decode, cannot be un-bubbled until if (should_bubble) statement
      if (!should_bubble)
        should_bubble <= is_br_DE;
      //else if(!from_AGEX_br_cond)
      else if (from_AGEX_is_br)
        should_bubble <= 0;
     end
  end

endmodule




module SXT(IN, OUT);
  parameter IBITS = 16;
  parameter OBITS = 32;

  input  [IBITS-1:0] IN;
  output [OBITS-1:0] OUT;

  assign OUT = {{(OBITS-IBITS){IN[IBITS-1]}}, IN};
endmodule

