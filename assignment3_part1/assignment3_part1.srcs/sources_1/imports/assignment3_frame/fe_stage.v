 `include "VX_define.vh" 


module FE_STAGE(
  input clk,
  input reset,
  input [`from_DE_to_FE_WIDTH-1:0] from_DE_to_FE,
  input [`from_AGEX_to_FE_WIDTH-1:0] from_AGEX_to_FE,   
  input [`from_MEM_to_FE_WIDTH-1:0] from_MEM_to_FE,   
  input [`from_WB_to_FE_WIDTH-1:0] from_WB_to_FE, 
  output[`FE_latch_WIDTH-1:0] FE_latch_out
);


  // I-MEM
  (* ram_init_file = `IDMEMINITFILE *)
  reg [`DBITS-1:0] imem [`IMEMWORDS-1:0];
 
   initial begin
        $readmemh(`IDMEMINITFILE , imem);
  end

/* pipeline latch */ 
  reg [`FE_latch_WIDTH-1:0] FE_latch;  // FE latch 

  reg [`DBITS-1:0] PC_FE_latch; // PC latch in the FE stage   // you could use a part of FE_latch as a PC latch as well 
  
  wire [`INSTBITS-1:0] inst_FE;  // instruction value in the FE stage 
  wire [`DBITS-1:0] pcplus_FE;  // pc plus value in the FE stage 
  wire stall_pipe; // signal to indicate when a front-end needs to be stall
  
  wire [`FE_latch_WIDTH-1:0] FE_latch_contents; 
  wire [`INSTBITS-1:0] inst_predict;
  
  // From AGEX
  wire one;
  wire two;
  wire from_AGEX_is_jmp;
  wire from_AGEX_is_br;
  wire pctarget_AGEX_jmp;
  wire pctarget_AGEX;
  
  // reading instruction from imem 
  assign inst_FE = imem[PC_FE_latch[`IMEMADDRBITS-1:`IMEMWORDBITS]];
  assign inst_predict = imem[pcplus_FE[`IMEMADDRBITS-1:`IMEMWORDBITS]]; //use for coming out of stall, if not BR to target
  
  // wire to send the FE latch contents to the DE stage 
  assign FE_latch_out = FE_latch;

  // This is the value of "incremented PC", computed in the FE stage
  assign pcplus_FE = PC_FE_latch + `INSTSIZE;
  
   
   // the order of latch contents should be matched in the decode stage when we extract the contents. 
  assign FE_latch_contents = { 
                                (from_AGEX_is_br) ? inst_predict : inst_FE, 
                                PC_FE_latch, 
                                pcplus_FE,
                                 // please feel free to add more signals such as valid bits etc. 
                                // if you add more bits here, please increase the width of latch in VX_define.vh 
                                `BUS_CANARY_VALUE // for an error checking of bus encoding/decoding  
                                };
   assign  {
                              one,
                              two,
                              from_AGEX_is_jmp,
                              from_AGEX_is_br,
                              pctarget_AGEX,
                              pctarget_AGEX_jmp
                              } = from_AGEX_to_FE; 
   
  assign stall_pipe = (((inst_FE[31:28] == 4'b0010) || (inst_FE[31:28] == 4'b0011) && !(from_AGEX_is_br || from_AGEX_is_jmp)));
//                           || (from_DE_bb_table[inst_FE[/*readreg1*/]] == 1|| from_DE_bb_table[inst_FE[]] == 1)); // you need to complete the logic to compute stall FE stage 
   
  always @ (posedge clk or posedge reset) begin
    if(reset)
      PC_FE_latch <= `STARTPC;
    else if(!stall_pipe) begin
            if(from_AGEX_is_br)
                PC_FE_latch <= pctarget_AGEX;
            else if (from_AGEX_is_jmp)
                PC_FE_latch <= pctarget_AGEX_jmp;
            else
                PC_FE_latch <= pcplus_FE;         
         end
    else
      PC_FE_latch <= PC_FE_latch;
  end
  

  always @ (posedge clk or posedge reset) begin
    if(reset) 
        begin 
        FE_latch <= {`FE_latch_WIDTH{1'b0}}; 
        end 
     else   // this is just an example. you need to expand the contents of if/else
        begin  
            FE_latch <= FE_latch_contents; 
        end  
  end
 
 
 
endmodule