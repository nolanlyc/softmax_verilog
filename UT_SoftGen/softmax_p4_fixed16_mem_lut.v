//softmax_p4_smem_rfixed16_alut_v512_b2_0_10.v
`ifndef DEFINES_DONE
`define DEFINES_DONE
`define EXPONENT 5
`define MANTISSA 10
`define SIGN 1
`define DATAWIDTH (`SIGN+`EXPONENT+`MANTISSA)
`define IEEE_COMPLIANCE 1
`define NUM 4
`define ADDRSIZE 8
`define ADDRSIZE_FOR_TB 10
`define ACTUAL_MANTISSA 11
`define EXPONENT_LSB 10
`define EXPONENT_MSB 14
`define MANTISSA_LSB 0
`define MANTISSA_MSB 9
`define MANTISSA_MUL_SPLIT_LSB 3
`define MANTISSA_MUL_SPLIT_MSB 9
`define SIGN_LOC 15
`define DWIDTH (`SIGN+`EXPONENT+`MANTISSA)
`define IEEE_COMPLIANCE 1
`endif


`timescale 1ns / 1ps

//fixed adder adds unsigned fixed numbers. Overflow flag is high in case of overflow
module softmax(
  inp,      //data in from memory to max block
  sub0_inp, //data inputs from memory to first-stage subtractors
  sub1_inp, //data inputs from memory to second-stage subtractors

  start_addr,   //the first address that contains input data in the on-chip memory
  end_addr,     //max address containing required data

  addr,          //address corresponding to data inp
  sub0_inp_addr, //address corresponding to sub0_inp
  sub1_inp_addr, //address corresponding to sub1_inp
  addr_sel,
  outp0,
  outp1,
  outp2,
  outp3,

  clk,
  reset,
  init,   //the signal indicating to latch the new start address
  done,   //done signal asserts when the softmax calculation is over
  start); //start signal for the overall softmax operation

  input clk;
  input reset;
  input start;
  input init;

  input  [`DATAWIDTH*`NUM-1:0] inp;
  input  [`DATAWIDTH*`NUM-1:0] sub0_inp;
  input  [`DATAWIDTH*`NUM-1:0] sub1_inp;
  input  [`ADDRSIZE-1:0]       end_addr;
  input  [`ADDRSIZE-1:0]       start_addr;

  output [`ADDRSIZE-1 :0] addr;
  output  [`ADDRSIZE-1:0] sub0_inp_addr;
  output  [`ADDRSIZE-1:0] sub1_inp_addr;
  output addr_sel;
  output [`DATAWIDTH-1:0] outp0;
  output [`DATAWIDTH-1:0] outp1;
  output [`DATAWIDTH-1:0] outp2;
  output [`DATAWIDTH-1:0] outp3;
  output done;

  reg [`DATAWIDTH*`NUM-1:0] inp_reg;
  reg [`ADDRSIZE-1:0] addr;
  reg [`DATAWIDTH*`NUM-1:0] sub0_inp_reg;
  reg [`DATAWIDTH*`NUM-1:0] sub1_inp_reg;
  reg [`ADDRSIZE-1:0] sub0_inp_addr;
  reg [`ADDRSIZE-1:0] sub1_inp_addr;


  ////-----------control signals--------------////
  reg mode1_start;
  reg mode1_run;
  reg mode2_start;
  reg mode2_run;

  reg mode3_stage_run2;
  reg mode3_stage_run;
  reg mode7_stage_run2;
  reg mode7_stage_run;
  
  reg mode3_run;

  reg mode1_stage1_run_a;
  reg mode1_stage0_run;
  reg mode1_stage1_run;
  wire mode1_stage2_run;
  assign mode1_stage2_run = mode1_run;

  reg mode4_stage1_run_a;
  reg mode4_stage2_run_a;
  reg mode4_stage0_run;
  reg mode4_stage1_run;
  reg mode4_stage2_run;

  reg mode5_run;
  reg mode6_run;
  reg mode7_run;
  reg presub_start;
  reg presub_run;
  reg presub_run_2;
  reg presub_run_1;
  reg presub_run_0;
  reg done;

  assign addr_sel = mode1_run & ~mode2_start;

  always @(posedge clk)begin
    mode4_stage1_run_a <= mode4_stage1_run;
    mode4_stage2_run_a <= mode4_stage2_run;
  end

  always @(posedge clk)begin
    mode1_stage1_run_a <= mode1_stage1_run;
  end

  always @(posedge clk) begin
    if(reset) begin
      addr <= 0;
      mode1_start <= 0;
      mode1_run <= 0;
    end
    //init latch the input address
    else if(init) begin
      addr <= start_addr;
    end
    //start the mode1 max calculation
    else if(start)begin
      mode1_start <= 1;
    end
    //logic when to finish mode1 and trigger mode2 to latch the mode2 address
    else if(mode1_start && addr < end_addr) begin 
      addr <= addr + 1;
      mode1_run <= 1;
    end else if(addr == end_addr)begin 
      addr <= 0;
      mode1_run <= 0;
      mode1_start <= 0;
    end else begin
      mode1_run <= 0;
    end
  end

   //always @(posedge clk) begin
   // if(reset) begin
   //   mode1_stage2_run <= 0;
   // end
   // else if (mode1_run == 1) begin
   //   mode1_stage2_run <= 1;
   // end
   // else begin
   //   mode1_stage2_run <= 0;
   // end
   //end

  always @(posedge clk) begin
    if(reset) begin
      mode1_stage1_run <= 0;
    end
    else if (mode1_stage2_run == 1) begin
      mode1_stage1_run <= 1;
    end
    else begin
      mode1_stage1_run <= 0;
    end
  end
  
    always @(posedge clk) begin
    if(reset) begin
      mode1_stage0_run <= 0;
    end
    else if (mode1_stage1_run == 1) begin
      mode1_stage0_run <= 1;
    end
    else begin
      mode1_stage0_run <= 0;
    end
  end

  always @(posedge clk) begin
    if(reset) begin
      sub0_inp_addr <= 0;
      sub0_inp_reg <= 0;
      mode2_start <= 0;
      mode2_run <= 0;
    end
    else if (mode1_stage1_run_a & ~mode1_stage1_run) begin
    //else if ((mode1_start) && (addr == (end_addr - 1))) begin
        mode2_start <= 1;
        sub0_inp_addr <= start_addr;
	end
    //logic when to finish mode2
    else if(mode2_start && sub0_inp_addr < end_addr) begin
      sub0_inp_addr <= sub0_inp_addr + 1;
      sub0_inp_reg <= sub0_inp;
      mode2_run <= 1;
    end 
	else if(sub0_inp_addr == end_addr)begin
      sub0_inp_addr <= 0;
      sub0_inp_reg <= 0;
      mode2_run <= 0;
      mode2_start <= 0;
    end
  end	

  always @(posedge clk) begin
    if(reset) begin
      mode3_stage_run2 <= 0;
    end
    //logic when to trigger mode3
    else if(mode2_run == 1) begin
      mode3_stage_run2 <= 1;
    end else begin
      mode3_stage_run2 <= 0;
    end
  end	

  always @(posedge clk) begin
    if(reset) begin
      mode3_stage_run <= 0;
    end
    else if(mode3_stage_run2 == 1) begin
      mode3_stage_run <= 1;
    end else begin
      mode3_stage_run <= 0;
    end
  end	

  always @(posedge clk) begin
    if(reset) begin
      mode3_run <= 0;
    end
    else if(mode3_stage_run == 1) begin
      mode3_run <= 1;
    end else begin
      mode3_run <= 0;
    end
  end

  always @(posedge clk) begin
    if(reset) begin
      mode4_stage2_run <= 0;
    end
    //logic when to trigger mode4 last stage adderTree, since the final results of adderTree
    //is always ready 1 cycle after mode3 finishes, so there is no need on extra
    //logic to control the adderTree outputs
    else if (mode3_run == 1) begin
      mode4_stage2_run <= 1;
    end else begin
      mode4_stage2_run <= 0;
    end
  end

  always @(posedge clk) begin
    if(reset) begin
      mode4_stage1_run <= 0;
    end
    else if (mode4_stage2_run == 1) begin
      mode4_stage1_run <= 1;
    end else begin
      mode4_stage1_run <= 0;
    end
  end

  always @(posedge clk) begin
    if(reset) begin
      mode4_stage0_run <= 0;
    end
    else if (mode4_stage1_run == 1) begin
      mode4_stage0_run <= 1;
    end else begin
      mode4_stage0_run <= 0;
    end
  end

  reg mode5_stage0_run;
  reg mode5_stage1_run;
  reg mode5_stage2_run;  
  wire mode5_stage3_run = mode5_run;

  always @(posedge clk) begin
    if(reset) begin
      mode5_run <= 0;
    end
    //mode5 should be triggered right at the falling edge of mode4_stage1_run
    else if(mode4_stage1_run_a & ~mode4_stage1_run) begin
      mode5_run <= 1;
    end 
	else if(mode4_stage1_run == 0) begin
      mode5_run <= 0;
    end
  end
  
  always @(posedge clk) begin
    if(reset) begin
      mode5_stage2_run <= 0;
    end
    else if (mode5_stage3_run == 1) begin
      mode5_stage2_run <= 1;
    end
    else begin
      mode5_stage2_run <= 0;
    end
  end
    always @(posedge clk) begin
    if(reset) begin
      mode5_stage1_run <= 0;
    end
    else if (mode5_stage2_run == 1) begin
      mode5_stage1_run <= 1;
    end
    else begin
      mode5_stage1_run <= 0;
    end
  end
  
    always @(posedge clk) begin
    if(reset) begin
      mode5_stage0_run <= 0;
    end
    else if (mode5_stage1_run == 1) begin
      mode5_stage0_run <= 1;
    end
    else begin
      mode5_stage0_run <= 0;
    end
  end

  always @(posedge clk) begin
    if(reset) begin
      presub_start <= 0;
      sub1_inp_addr <= 0;
      sub1_inp_reg <= 0;
      presub_run <= 0;
    end
    else if(mode4_stage2_run_a & ~mode4_stage2_run) begin
      presub_start <= 1;
      sub1_inp_addr <= start_addr;
      sub1_inp_reg <= sub1_inp;
    end
    else if(~reset && presub_start && sub1_inp_addr < end_addr)begin
      sub1_inp_addr <= sub1_inp_addr + 1;
      sub1_inp_reg <= sub1_inp;
      presub_run <= 1;
    end 
	else if(sub1_inp_addr == end_addr) begin
      presub_run <= 0;
      presub_start <= 0;
      sub1_inp_addr <= 0;
      sub1_inp_reg <= 0;
    end
  end

   always @(posedge clk) begin
    if(reset) begin
      presub_run_2 <= 0;
    end
    else if (presub_run == 1) begin
      presub_run_2 <= 1;
    end
    else begin
      presub_run_2 <= 0;
    end
  end

   always @(posedge clk) begin
    if(reset) begin
      presub_run_1 <= 0;
    end
    else if (presub_run_2 == 1) begin
      presub_run_1 <= 1;
    end
    else begin
      presub_run_1 <= 0;
    end
  end

   always @(posedge clk) begin
    if(reset) begin
      presub_run_0 <= 0;
    end
    else if (presub_run_1 == 1) begin
      presub_run_0 <= 1;
    end
    else begin
      presub_run_0 <= 0;
    end
  end

  always @(posedge clk) begin
    if(reset) begin
      mode6_run <= 0;
	end  
    else if(presub_run_0) begin
      mode6_run <= 1;
    end else begin
      mode6_run <= 0;
    end
  end

  always @(posedge clk) begin
    if(reset) begin
      mode7_stage_run2 <= 0;
	end
    else if(mode6_run == 1) begin
      mode7_stage_run2 <= 1;
    end else begin
      mode7_stage_run2 <= 0;
    end
  end

  always @(posedge clk) begin
    if(reset) begin
      mode7_stage_run <= 0;
	end
    else if(mode7_stage_run2 == 1) begin
      mode7_stage_run <= 1;
    end else begin
      mode7_stage_run <= 0;
    end
  end 
  
  always @(posedge clk) begin
    if(reset) begin
      mode7_run <= 0;
	end
	else if(mode7_stage_run == 1) begin
      mode7_run <= 1;
    end else begin
      mode7_run <= 0;
    end
  end

  always @(posedge clk) begin
    if(reset) begin
      done <= 0;
	end  
    else if(mode7_run) begin
      done <= 1;
    end else begin
      done <= 0;
    end
  end

  ////------mode1 max block---------///////
  wire [`DATAWIDTH-1:0] max_outp;

  mode1_max_tree mode1_max(
      .inp0(inp[`DATAWIDTH*1-1:`DATAWIDTH*0]),
      .inp1(inp[`DATAWIDTH*2-1:`DATAWIDTH*1]),
      .inp2(inp[`DATAWIDTH*3-1:`DATAWIDTH*2]),
      .inp3(inp[`DATAWIDTH*4-1:`DATAWIDTH*3]),
      .mode1_stage2_run(mode1_stage2_run),
      .mode1_stage1_run(mode1_stage1_run),
      .mode1_stage0_run(mode1_stage0_run),
      .clk(clk),
      .reset(reset),
      .outp(max_outp));

  ////------mode2 subtraction---------///////
  wire [`DATAWIDTH-1:0] mode2_outp_sub0;
  wire [`DATAWIDTH-1:0] mode2_outp_sub1;
  wire [`DATAWIDTH-1:0] mode2_outp_sub2;
  wire [`DATAWIDTH-1:0] mode2_outp_sub3;
  mode2_sub mode2_sub(
      .a_inp0(sub0_inp_reg[`DATAWIDTH*1-1:`DATAWIDTH*0]),
      .a_inp1(sub0_inp_reg[`DATAWIDTH*2-1:`DATAWIDTH*1]),
      .a_inp2(sub0_inp_reg[`DATAWIDTH*3-1:`DATAWIDTH*2]),
      .a_inp3(sub0_inp_reg[`DATAWIDTH*4-1:`DATAWIDTH*3]),
      .outp0(mode2_outp_sub0),
      .outp1(mode2_outp_sub1),
      .outp2(mode2_outp_sub2),
      .outp3(mode2_outp_sub3),
      .b_inp(max_outp));

  reg [`DATAWIDTH-1:0] mode2_outp_sub0_reg;
  reg [`DATAWIDTH-1:0] mode2_outp_sub1_reg;
  reg [`DATAWIDTH-1:0] mode2_outp_sub2_reg;
  reg [`DATAWIDTH-1:0] mode2_outp_sub3_reg;
  always @(posedge clk) begin
    if (reset) begin
      mode2_outp_sub0_reg <= 0;
      mode2_outp_sub1_reg <= 0;
      mode2_outp_sub2_reg <= 0;
      mode2_outp_sub3_reg <= 0;
    end else if (mode2_run) begin
      mode2_outp_sub0_reg <= mode2_outp_sub0;
      mode2_outp_sub1_reg <= mode2_outp_sub1;
      mode2_outp_sub2_reg <= mode2_outp_sub2;
      mode2_outp_sub3_reg <= mode2_outp_sub3;
    end
  end

  ////------mode3 exponential---------///////
  wire [`DATAWIDTH-1:0] mode3_outp_exp0;
  wire [`DATAWIDTH-1:0] mode3_outp_exp1;
  wire [`DATAWIDTH-1:0] mode3_outp_exp2;
  wire [`DATAWIDTH-1:0] mode3_outp_exp3;
  mode3_exp mode3_exp(
      .inp0(mode2_outp_sub0_reg),
      .inp1(mode2_outp_sub1_reg),
      .inp2(mode2_outp_sub2_reg),
      .inp3(mode2_outp_sub3_reg),

      .clk(clk),
      .reset(reset),
      .stage_run(mode3_stage_run),
      .stage_run2(mode3_stage_run2),

      .outp0(mode3_outp_exp0),
      .outp1(mode3_outp_exp1),
      .outp2(mode3_outp_exp2),
      .outp3(mode3_outp_exp3)
  );

  reg [`DATAWIDTH-1:0] mode3_outp_exp0_reg;
  reg [`DATAWIDTH-1:0] mode3_outp_exp1_reg;
  reg [`DATAWIDTH-1:0] mode3_outp_exp2_reg;
  reg [`DATAWIDTH-1:0] mode3_outp_exp3_reg;
  always @(posedge clk) begin
    if (reset) begin
      mode3_outp_exp0_reg <= 0;
      mode3_outp_exp1_reg <= 0;
      mode3_outp_exp2_reg <= 0;
      mode3_outp_exp3_reg <= 0;
    end else if (mode3_run) begin
      mode3_outp_exp0_reg <= mode3_outp_exp0;
      mode3_outp_exp1_reg <= mode3_outp_exp1;
      mode3_outp_exp2_reg <= mode3_outp_exp2;
      mode3_outp_exp3_reg <= mode3_outp_exp3;
    end
  end

  //////------mode4 pipelined adder tree---------///////
  wire [`DATAWIDTH-1:0] mode4_adder_tree_outp;
  mode4_adder_tree mode4_adder_tree(
    .inp0(mode3_outp_exp0_reg),
    .inp1(mode3_outp_exp1_reg),
    .inp2(mode3_outp_exp2_reg),
    .inp3(mode3_outp_exp3_reg),
    .mode4_stage2_run(mode4_stage2_run),
    .mode4_stage1_run(mode4_stage1_run),
    .mode4_stage0_run(mode4_stage0_run),

    .clk(clk),
    .reset(reset),
    .outp(mode4_adder_tree_outp)
  );


  //////------mode5 log---------///////
  wire [`DATAWIDTH-1:0] mode5_outp_log;
  reg  [`DATAWIDTH-1:0] mode5_outp_log_reg;
  mode5_ln mode5_ln(.inp(mode4_adder_tree_outp), .outp(mode5_outp_log), .clk(clk), .reset(reset), .mode5_stage3_run(mode5_stage3_run), .mode5_stage2_run(mode5_stage2_run), .mode5_stage1_run(mode5_stage1_run) );

  always @(posedge clk) begin
    if(reset) begin
      mode5_outp_log_reg <= 0;
    end else if(mode5_stage0_run) begin
      mode5_outp_log_reg <= mode5_outp_log;
    end
  end

  //////------mode6 pre-sub---------///////
  wire [`DATAWIDTH-1:0] mode6_outp_presub0;
  wire [`DATAWIDTH-1:0] mode6_outp_presub1;
  wire [`DATAWIDTH-1:0] mode6_outp_presub2;
  wire [`DATAWIDTH-1:0] mode6_outp_presub3;
  reg [`DATAWIDTH-1:0] mode6_outp_presub0_reg_3;
  reg [`DATAWIDTH-1:0] mode6_outp_presub1_reg_3;
  reg [`DATAWIDTH-1:0] mode6_outp_presub2_reg_3;
  reg [`DATAWIDTH-1:0] mode6_outp_presub3_reg_3;
  reg [`DATAWIDTH-1:0] mode6_outp_presub0_reg_2;
  reg [`DATAWIDTH-1:0] mode6_outp_presub1_reg_2;
  reg [`DATAWIDTH-1:0] mode6_outp_presub2_reg_2;
  reg [`DATAWIDTH-1:0] mode6_outp_presub3_reg_2;
  reg [`DATAWIDTH-1:0] mode6_outp_presub0_reg_1;
  reg [`DATAWIDTH-1:0] mode6_outp_presub1_reg_1;
  reg [`DATAWIDTH-1:0] mode6_outp_presub2_reg_1;
  reg [`DATAWIDTH-1:0] mode6_outp_presub3_reg_1;
  reg [`DATAWIDTH-1:0] mode6_outp_presub0_reg_0;
  reg [`DATAWIDTH-1:0] mode6_outp_presub1_reg_0;
  reg [`DATAWIDTH-1:0] mode6_outp_presub2_reg_0;
  reg [`DATAWIDTH-1:0] mode6_outp_presub3_reg_0;



  mode6_sub pre_sub(
      .a_inp0(sub1_inp_reg[`DATAWIDTH*1-1:`DATAWIDTH*0]),
      .a_inp1(sub1_inp_reg[`DATAWIDTH*2-1:`DATAWIDTH*1]),
      .a_inp2(sub1_inp_reg[`DATAWIDTH*3-1:`DATAWIDTH*2]),
      .a_inp3(sub1_inp_reg[`DATAWIDTH*4-1:`DATAWIDTH*3]),
      .b_inp(max_outp),
      .outp0(mode6_outp_presub0),
      .outp1(mode6_outp_presub1),
      .outp2(mode6_outp_presub2),
      .outp3(mode6_outp_presub3)
  );
  always @(posedge clk) begin
    if (reset) begin
      mode6_outp_presub0_reg_3 <= 0;
      mode6_outp_presub1_reg_3 <= 0;
      mode6_outp_presub2_reg_3 <= 0;
      mode6_outp_presub3_reg_3 <= 0;
    end else if (presub_run) begin
      mode6_outp_presub0_reg_3 <= mode6_outp_presub0;
      mode6_outp_presub1_reg_3 <= mode6_outp_presub1;
      mode6_outp_presub2_reg_3 <= mode6_outp_presub2;
      mode6_outp_presub3_reg_3 <= mode6_outp_presub3;
    end
  end
  
  always @(posedge clk) begin
    if (reset) begin
      mode6_outp_presub0_reg_2 <= 0;
      mode6_outp_presub1_reg_2 <= 0;
      mode6_outp_presub2_reg_2 <= 0;
      mode6_outp_presub3_reg_2 <= 0;
    end else if (presub_run_2) begin
      mode6_outp_presub0_reg_2 <= mode6_outp_presub0_reg_3;
      mode6_outp_presub1_reg_2 <= mode6_outp_presub1_reg_3;
      mode6_outp_presub2_reg_2 <= mode6_outp_presub2_reg_3;
      mode6_outp_presub3_reg_2 <= mode6_outp_presub3_reg_3;
    end
  end

  always @(posedge clk) begin
    if (reset) begin
      mode6_outp_presub0_reg_1 <= 0;
      mode6_outp_presub1_reg_1 <= 0;
      mode6_outp_presub2_reg_1 <= 0;
      mode6_outp_presub3_reg_1 <= 0;
    end else if (presub_run_1) begin
      mode6_outp_presub0_reg_1 <= mode6_outp_presub0_reg_2;
      mode6_outp_presub1_reg_1 <= mode6_outp_presub1_reg_2;
      mode6_outp_presub2_reg_1 <= mode6_outp_presub2_reg_2;
      mode6_outp_presub3_reg_1 <= mode6_outp_presub3_reg_2;
    end
  end
  
  always @(posedge clk) begin
    if (reset) begin
      mode6_outp_presub0_reg_0 <= 0;
      mode6_outp_presub1_reg_0 <= 0;
      mode6_outp_presub2_reg_0 <= 0;
      mode6_outp_presub3_reg_0 <= 0;
    end else if (presub_run_0) begin
      mode6_outp_presub0_reg_0 <= mode6_outp_presub0_reg_1;
      mode6_outp_presub1_reg_0 <= mode6_outp_presub1_reg_1;
      mode6_outp_presub2_reg_0 <= mode6_outp_presub2_reg_1;
      mode6_outp_presub3_reg_0 <= mode6_outp_presub3_reg_1;
    end
  end

  //////------mode6 logsub ---------///////
  wire [`DATAWIDTH-1:0] mode6_outp_logsub0;
  wire [`DATAWIDTH-1:0] mode6_outp_logsub1;
  wire [`DATAWIDTH-1:0] mode6_outp_logsub2;
  wire [`DATAWIDTH-1:0] mode6_outp_logsub3;
  reg [`DATAWIDTH-1:0] mode6_outp_logsub0_reg;
  reg [`DATAWIDTH-1:0] mode6_outp_logsub1_reg;
  reg [`DATAWIDTH-1:0] mode6_outp_logsub2_reg;
  reg [`DATAWIDTH-1:0] mode6_outp_logsub3_reg;

  mode6_sub log_sub(
      .a_inp0(mode6_outp_presub0_reg_0),
      .a_inp1(mode6_outp_presub1_reg_0),
      .a_inp2(mode6_outp_presub2_reg_0),
      .a_inp3(mode6_outp_presub3_reg_0),
      .b_inp(mode5_outp_log_reg),
      .outp0(mode6_outp_logsub0),
      .outp1(mode6_outp_logsub1),
      .outp2(mode6_outp_logsub2),
      .outp3(mode6_outp_logsub3)
  );
  always @(posedge clk) begin
    if (reset) begin
      mode6_outp_logsub0_reg <= 0;
      mode6_outp_logsub1_reg <= 0;
      mode6_outp_logsub2_reg <= 0;
      mode6_outp_logsub3_reg <= 0;
    end else if (mode6_run) begin
      mode6_outp_logsub0_reg <= mode6_outp_logsub0;
      mode6_outp_logsub1_reg <= mode6_outp_logsub1;
      mode6_outp_logsub2_reg <= mode6_outp_logsub2;
      mode6_outp_logsub3_reg <= mode6_outp_logsub3;
    end
  end

  //////------mode7 exp---------///////
  wire [`DATAWIDTH-1:0] outp0_temp;
  wire [`DATAWIDTH-1:0] outp1_temp;
  wire [`DATAWIDTH-1:0] outp2_temp;
  wire [`DATAWIDTH-1:0] outp3_temp;
  reg [`DATAWIDTH-1:0] outp0;
  reg [`DATAWIDTH-1:0] outp1;
  reg [`DATAWIDTH-1:0] outp2;
  reg [`DATAWIDTH-1:0] outp3;

  mode7_exp mode7_exp(
      .inp0(mode6_outp_logsub0_reg),
      .inp1(mode6_outp_logsub1_reg),
      .inp2(mode6_outp_logsub2_reg),
      .inp3(mode6_outp_logsub3_reg),

      .clk(clk),
      .reset(reset),
      .stage_run(mode7_stage_run),
      .stage_run2(mode7_stage_run2),

      .outp0(outp0_temp),
      .outp1(outp1_temp),
      .outp2(outp2_temp),
      .outp3(outp3_temp)
  );
  always @(posedge clk) begin
    if (reset) begin
      outp0 <= 0;
      outp1 <= 0;
      outp2 <= 0;
      outp3 <= 0;
    end else if (mode7_run) begin
      outp0 <= outp0_temp;
      outp1 <= outp1_temp;
      outp2 <= outp2_temp;
      outp3 <= outp3_temp;
    end
  end

endmodule



module mode1_max_tree(
  inp0, 
  inp1, 
  inp2, 
  inp3, 
 
  mode1_stage2_run,
  mode1_stage1_run,
  mode1_stage0_run,
  clk,
  reset,
  outp

);

  input  [`DATAWIDTH-1 : 0] inp0; 
  input  [`DATAWIDTH-1 : 0] inp1; 
  input  [`DATAWIDTH-1 : 0] inp2; 
  input  [`DATAWIDTH-1 : 0] inp3; 

  input mode1_stage2_run;
  input mode1_stage1_run;	
  input mode1_stage0_run;
  input clk;
  input reset;

  output reg [`DATAWIDTH-1 : 0] outp;

  wire   [`DATAWIDTH-1 : 0] cmp0_out_stage2;
  wire   [`DATAWIDTH-1 : 0] cmp1_out_stage2;
  wire   [`DATAWIDTH-1 : 0] cmp0_out_stage1;
  wire   [`DATAWIDTH-1 : 0] cmp0_out_stage0;

  reg   [`DATAWIDTH-1 : 0] cmp0_out_stage2_reg;
  reg   [`DATAWIDTH-1 : 0] cmp1_out_stage2_reg;
  reg   [`DATAWIDTH-1 : 0] cmp0_out_stage1_reg;
  
  always @(posedge clk) begin
    if (reset) begin
      outp <= 0;
    end

    else if(~reset && mode1_stage0_run) begin
      outp <= cmp0_out_stage0;
    end

  end

wire cmp0_stage2_aeb;
wire cmp0_stage2_aneb;
wire cmp0_stage2_alb;
wire cmp0_stage2_aleb;
wire cmp0_stage2_agb;
wire cmp0_stage2_ageb;
wire cmp0_stage2_unordered;

wire cmp1_stage2_aeb;
wire cmp1_stage2_aneb;
wire cmp1_stage2_alb;
wire cmp1_stage2_aleb;
wire cmp1_stage2_agb;
wire cmp1_stage2_ageb;
wire cmp1_stage2_unordered;

wire cmp0_stage1_aeb;
wire cmp0_stage1_aneb;
wire cmp0_stage1_alb;
wire cmp0_stage1_aleb;
wire cmp0_stage1_agb;
wire cmp0_stage1_ageb;
wire cmp0_stage1_unordered;

wire cmp0_stage0_aeb;
wire cmp0_stage0_aneb;
wire cmp0_stage0_alb;
wire cmp0_stage0_aleb;
wire cmp0_stage0_agb;
wire cmp0_stage0_ageb;
wire cmp0_stage0_unordered;

comparator cmp0_stage2(.a(inp0),       .b(inp1),        .aeb(cmp0_stage2_aeb), .aneb(cmp0_stage2_aneb), .alb(cmp0_stage2_alb), .aleb(cmp0_stage2_aleb), .agb(cmp0_stage2_agb), .ageb(cmp0_stage2_ageb), .unordered(cmp0_stage2_unordered));
assign cmp0_out_stage2 = (cmp0_stage2_ageb==1'b1) ? inp0 : inp1;

comparator cmp1_stage2(.a(inp2),       .b(inp3),         .aeb(cmp1_stage2_aeb), .aneb(cmp1_stage2_aneb), .alb(cmp1_stage2_alb), .aleb(cmp1_stage2_aleb), .agb(cmp1_stage2_agb), .ageb(cmp1_stage2_ageb), .unordered(cmp1_stage2_unordered));   
assign cmp1_out_stage2 = (cmp1_stage2_ageb==1'b1) ? inp2 : inp3;

always @(posedge clk) begin
	if (reset) begin
		cmp0_out_stage2_reg <= 16'b0;
		cmp1_out_stage2_reg <= 16'b0;
	end
	else if (~reset && mode1_stage2_run) begin
		cmp0_out_stage2_reg <= cmp0_out_stage2;
		cmp1_out_stage2_reg <= cmp1_out_stage2;
	end
end

comparator cmp0_stage1(.a(cmp0_out_stage2_reg),       .b(cmp1_out_stage2_reg),          .aeb(cmp0_stage1_aeb), .aneb(cmp0_stage1_aneb), .alb(cmp0_stage1_alb), .aleb(cmp0_stage1_aleb), .agb(cmp0_stage1_agb), .ageb(cmp0_stage1_ageb), .unordered(cmp0_stage1_unordered));
assign cmp0_out_stage1 = (cmp0_stage1_ageb==1'b1) ? cmp0_out_stage2_reg: cmp1_out_stage2_reg;

always @(posedge clk) begin
	if (reset) begin
		cmp0_out_stage1_reg <= 16'b0;
	end
	else if (~reset && mode1_stage1_run) begin
		cmp0_out_stage1_reg <= cmp0_out_stage1;

	end
end

comparator cmp0_stage0(.a(outp),       .b(cmp0_out_stage1_reg),         .aeb(cmp0_stage0_aeb), .aneb(cmp0_stage0_aneb), .alb(cmp0_stage0_alb), .aleb(cmp0_stage0_aleb), .agb(cmp0_stage0_agb), .ageb(cmp0_stage0_ageb), .unordered(cmp0_stage0_unordered));
assign cmp0_out_stage0 = (cmp0_stage0_ageb==1'b1) ? outp : cmp0_out_stage1_reg;

//DW_fp_cmp #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) cmp0_stage2(.a(inp0),       .b(inp1),      .z1(cmp0_out_stage2), .zctr(1'b0), .aeqb(), .altb(), .agtb(), .unordered(), .z0(), .status0(), .status1());
//DW_fp_cmp #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) cmp1_stage2(.a(inp2),       .b(inp3),      .z1(cmp1_out_stage2), .zctr(1'b0), .aeqb(), .altb(), .agtb(), .unordered(), .z0(), .status0(), .status1());
//
//DW_fp_cmp #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) cmp0_stage1(.a(cmp0_out_stage2),       .b(cmp1_out_stage2),      .z1(cmp0_out_stage1), .zctr(1'b0), .aeqb(), .altb(), .agtb(), .unordered(), .z0(), .status0(), .status1());
//
//DW_fp_cmp #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) cmp0_stage0(.a(outp),       .b(cmp0_out_stage1),      .z1(cmp0_out_stage0), .zctr(1'b0), .aeqb(), .altb(), .agtb(), .unordered(), .z0(), .status0(), .status1());

endmodule

	  
module mode2_sub(
  a_inp0,
  a_inp1,
  a_inp2,
  a_inp3,
  outp0,
  outp1,
  outp2,
  outp3,
  b_inp
);

  input  [`DATAWIDTH-1 : 0] a_inp0;
  input  [`DATAWIDTH-1 : 0] a_inp1;
  input  [`DATAWIDTH-1 : 0] a_inp2;
  input  [`DATAWIDTH-1 : 0] a_inp3;
  output  [`DATAWIDTH-1 : 0] outp0;
  output  [`DATAWIDTH-1 : 0] outp1;
  output  [`DATAWIDTH-1 : 0] outp2;
  output  [`DATAWIDTH-1 : 0] outp3;
  input  [`DATAWIDTH-1 : 0] b_inp;


  wire clk_NC;
  wire rst_NC;
  wire [4:0] flags_NC0, flags_NC1, flags_NC2, flags_NC3;

  // 0 add, 1 sub
  fixed_point_addsub sub0(.clk(clk_NC), .rst(rst_NC), .a(a_inp0),	.b(b_inp), .operation(1'b1),	.result(outp0), .flags(flags_NC0));
  fixed_point_addsub sub1(.clk(clk_NC), .rst(rst_NC), .a(a_inp1),	.b(b_inp), .operation(1'b1),	.result(outp1), .flags(flags_NC1));
  fixed_point_addsub sub2(.clk(clk_NC), .rst(rst_NC), .a(a_inp2),	.b(b_inp), .operation(1'b1),	.result(outp2), .flags(flags_NC2));
  fixed_point_addsub sub3(.clk(clk_NC), .rst(rst_NC), .a(a_inp3),	.b(b_inp), .operation(1'b1),	.result(outp3), .flags(flags_NC3));

//  DW_fp_sub #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) sub0(.a(a_inp0), .b(b_inp), .z(outp0), .rnd(3'b000), .status());
//  DW_fp_sub #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) sub1(.a(a_inp1), .b(b_inp), .z(outp1), .rnd(3'b000), .status());
//  DW_fp_sub #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) sub2(.a(a_inp2), .b(b_inp), .z(outp2), .rnd(3'b000), .status());
//  DW_fp_sub #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) sub3(.a(a_inp3), .b(b_inp), .z(outp3), .rnd(3'b000), .status());
endmodule


module mode3_exp(
  inp0, 
  inp1, 
  inp2, 
  inp3, 

  clk,
  reset,
  stage_run,
  stage_run2,
  
  outp0, 
  outp1, 
  outp2, 
  outp3
);

  input  [`DATAWIDTH-1 : 0] inp0;
  input  [`DATAWIDTH-1 : 0] inp1;
  input  [`DATAWIDTH-1 : 0] inp2;
  input  [`DATAWIDTH-1 : 0] inp3;

  input  clk;
  input  reset;
  input  stage_run;
  input  stage_run2;

  output  [`DATAWIDTH-1 : 0] outp0;
  output  [`DATAWIDTH-1 : 0] outp1;
  output  [`DATAWIDTH-1 : 0] outp2;
  output  [`DATAWIDTH-1 : 0] outp3;
  expunit exp0(.a(inp0), .z(outp0), .status(), .stage_run(stage_run), .stage_run2(stage_run2), .clk(clk), .reset(reset));
  expunit exp1(.a(inp1), .z(outp1), .status(), .stage_run(stage_run), .stage_run2(stage_run2), .clk(clk), .reset(reset));
  expunit exp2(.a(inp2), .z(outp2), .status(), .stage_run(stage_run), .stage_run2(stage_run2), .clk(clk), .reset(reset));
  expunit exp3(.a(inp3), .z(outp3), .status(), .stage_run(stage_run), .stage_run2(stage_run2), .clk(clk), .reset(reset));
endmodule


module mode4_adder_tree(
  inp0, 
  inp1, 
  inp2, 
  inp3, 
  mode4_stage0_run,
  mode4_stage1_run,
  mode4_stage2_run,

  clk,
  reset,
  outp
);

  input clk;
  input reset;
  input  [`DATAWIDTH-1 : 0] inp0; 
  input  [`DATAWIDTH-1 : 0] inp1; 
  input  [`DATAWIDTH-1 : 0] inp2; 
  input  [`DATAWIDTH-1 : 0] inp3; 
  output [`DATAWIDTH-1 : 0] outp;
  input mode4_stage0_run;
  input mode4_stage1_run;
  input mode4_stage2_run;

  wire   [`DATAWIDTH-1 : 0] add0_out_stage2;
  reg    [`DATAWIDTH-1 : 0] add0_out_stage2_reg;
  wire   [`DATAWIDTH-1 : 0] add1_out_stage2;
  reg    [`DATAWIDTH-1 : 0] add1_out_stage2_reg;

  wire   [`DATAWIDTH-1 : 0] add0_out_stage1;
  reg    [`DATAWIDTH-1 : 0] add0_out_stage1_reg;

  wire   [`DATAWIDTH-1 : 0] add0_out_stage0;
  reg    [`DATAWIDTH-1 : 0] outp;
/*
  always @(posedge clk) begin
    if (reset) begin
      outp <= 0;
      add0_out_stage2_reg <= 0;
      add1_out_stage2_reg <= 0;
      add0_out_stage1_reg <= 0;
    end

    if(~reset && mode4_stage2_run) begin
      add0_out_stage2_reg <= add0_out_stage2;
      add1_out_stage2_reg <= add1_out_stage2;
    end

    if(~reset && mode4_stage1_run) begin
      add0_out_stage1_reg <= add0_out_stage1;
    end

    if(~reset && mode4_stage0_run) begin
      outp <= add0_out_stage0;
    end
  end
*/
always @ (posedge clk) begin
	if(~reset && mode4_stage2_run) begin
      add0_out_stage2_reg <= add0_out_stage2;
      add1_out_stage2_reg <= add1_out_stage2;
    end
	
	else if (reset) begin
		add0_out_stage2_reg <= 0;
		add1_out_stage2_reg <= 0;
	end
end		

always @ (posedge clk) begin
	if(~reset && mode4_stage1_run) begin
      add0_out_stage1_reg <= add0_out_stage1;
    end
	else if (reset) begin
	add0_out_stage1_reg <= 0;
	end
end

always @ (posedge clk) begin
	if(~reset && mode4_stage0_run) begin
		outp <= add0_out_stage0;
    end
	else if (reset) begin
		outp <= 0;
	end
end	
		
	
  wire clk_NC;
  wire rst_NC;
  wire [4:0] flags_NC0, flags_NC1, flags_NC2, flags_NC3;

  // 0 add, 1 sub
  fixed_point_addsub add0_stage2(.clk(clk_NC), .rst(rst_NC), .a(inp0),	.b(inp1), .operation(1'b0),	.result(add0_out_stage2), .flags(flags_NC0));
  fixed_point_addsub add1_stage2(.clk(clk_NC), .rst(rst_NC), .a(inp2),	.b(inp3), .operation(1'b0),	.result(add1_out_stage2), .flags(flags_NC1));
  fixed_point_addsub add0_stage1(.clk(clk_NC), .rst(rst_NC), .a(add0_out_stage2_reg),	.b(add1_out_stage2_reg), .operation(1'b0),	.result(add0_out_stage1), .flags(flags_NC2));
  fixed_point_addsub add0_stage0(.clk(clk_NC), .rst(rst_NC), .a(outp),	.b(add0_out_stage1_reg), .operation(1'b0),	.result(add0_out_stage0), .flags(flags_NC3));

  //DW_fp_add #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) add0_stage2(.a(inp0),       .b(inp1),      .z(add0_out_stage2), .rnd(3'b000),    .status());
  //DW_fp_add #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) add1_stage2(.a(inp2),       .b(inp3),      .z(add1_out_stage2), .rnd(3'b000),    .status());

  //DW_fp_add #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) add0_stage1(.a(add0_out_stage2_reg),       .b(add1_out_stage2_reg),      .z(add0_out_stage1), .rnd(3'b000),    .status());

  //DW_fp_add #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) add0_stage0(.a(outp),       .b(add0_out_stage1_reg),      .z(add0_out_stage0), .rnd(3'b000),    .status());

endmodule

module mode5_ln(inp, outp, clk, reset, mode5_stage3_run, mode5_stage2_run, mode5_stage1_run);
  input  [`DATAWIDTH-1 : 0] inp;
  output [`DATAWIDTH-1 : 0] outp;
  input clk,reset;
  input mode5_stage3_run;
  input mode5_stage2_run;
  input mode5_stage1_run;	
  
  logunit ln(.fpin(inp), .fpout(outp), .status(), .clk(clk), .reset(reset), .mode5_stage3_run(mode5_stage3_run), .mode5_stage2_run(mode5_stage2_run), .mode5_stage1_run(mode5_stage1_run));
endmodule

module mode6_sub(
  a_inp0,
  a_inp1,
  a_inp2,
  a_inp3,
  b_inp,
  outp0,
  outp1,
  outp2,
  outp3
);

  input  [`DATAWIDTH-1 : 0] a_inp0;
  input  [`DATAWIDTH-1 : 0] a_inp1;
  input  [`DATAWIDTH-1 : 0] a_inp2;
  input  [`DATAWIDTH-1 : 0] a_inp3;
  input  [`DATAWIDTH-1 : 0] b_inp;
  output  [`DATAWIDTH-1 : 0] outp0;
  output  [`DATAWIDTH-1 : 0] outp1;
  output  [`DATAWIDTH-1 : 0] outp2;
  output  [`DATAWIDTH-1 : 0] outp3;

  wire [4:0] flags_NC0, flags_NC1, flags_NC2, flags_NC3;
  // 0 add, 1 sub
  wire clk_NC, rst_NC;
  fixed_point_addsub sub0(.clk(clk_NC), .rst(rst_NC), .a(a_inp0),	.b(b_inp), .operation(1'b1),	.result(outp0), .flags(flags_NC0));
  fixed_point_addsub sub1(.clk(clk_NC), .rst(rst_NC), .a(a_inp1),	.b(b_inp), .operation(1'b1),	.result(outp1), .flags(flags_NC1));
  fixed_point_addsub sub2(.clk(clk_NC), .rst(rst_NC), .a(a_inp2),	.b(b_inp), .operation(1'b1),	.result(outp2), .flags(flags_NC2));
  fixed_point_addsub sub3(.clk(clk_NC), .rst(rst_NC), .a(a_inp3),	.b(b_inp), .operation(1'b1),	.result(outp3), .flags(flags_NC3));

//  DW_fp_sub #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) sub0(.a(a_inp0), .b(b_inp), .z(outp0), .rnd(3'b000), .status());
//  DW_fp_sub #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) sub1(.a(a_inp1), .b(b_inp), .z(outp1), .rnd(3'b000), .status());
//  DW_fp_sub #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) sub2(.a(a_inp2), .b(b_inp), .z(outp2), .rnd(3'b000), .status());
//  DW_fp_sub #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) sub3(.a(a_inp3), .b(b_inp), .z(outp3), .rnd(3'b000), .status());
endmodule


module mode7_exp(
  inp0, 
  inp1, 
  inp2, 
  inp3, 

  clk,
  reset,
  stage_run,
  stage_run2,
  
  outp0, 
  outp1, 
  outp2, 
  outp3
);

  input  [`DATAWIDTH-1 : 0] inp0;
  input  [`DATAWIDTH-1 : 0] inp1;
  input  [`DATAWIDTH-1 : 0] inp2;
  input  [`DATAWIDTH-1 : 0] inp3;

  input  clk;
  input  reset;
  input  stage_run;
  input  stage_run2;

  output  [`DATAWIDTH-1 : 0] outp0;
  output  [`DATAWIDTH-1 : 0] outp1;
  output  [`DATAWIDTH-1 : 0] outp2;
  output  [`DATAWIDTH-1 : 0] outp3;
  expunit exp0(.a(inp0), .z(outp0), .status(), .stage_run(stage_run), .stage_run2(stage_run2), .clk(clk), .reset(reset));
  expunit exp1(.a(inp1), .z(outp1), .status(), .stage_run(stage_run), .stage_run2(stage_run2), .clk(clk), .reset(reset));
  expunit exp2(.a(inp2), .z(outp2), .status(), .stage_run(stage_run), .stage_run2(stage_run2), .clk(clk), .reset(reset));
  expunit exp3(.a(inp3), .z(outp3), .status(), .stage_run(stage_run), .stage_run2(stage_run2), .clk(clk), .reset(reset));
endmodule

//============================================================================
// Fixed point add/sub module
//============================================================================
/*
module fixed_point_addsub(
		clk,
		rst,
		a,
		b,
		operation,			// 0 add, 1 sub
		result,
		flags
	);
	
	// Clock and reset
	input clk ;										// Clock signal
	input rst ;										// Reset (active high, resets pipeline registers)
	
	// Input ports
  input signed [`DATAWIDTH-1:0] a ;								// Input A, a 32-bit floating point number
  input signed [`DATAWIDTH-1:0] b ;								// Input B, a 32-bit floating point number
	input operation ;								// Operation select signal
	
	// Output ports
  output  reg signed [`DATAWIDTH-1:0] result ;						// Result of the operation
	output [4:0] flags ;							// Flags indicating exceptions according to IEEE754
	
  reg [`DATAWIDTH:0] result_t ;
  wire [`DATAWIDTH-1:0] b_t ;
	
	assign b_t = ~b + 1;
	
	always@(*) begin
      if (operation == 1'b0) begin
			result_t = a + b;
		end
		else begin
			result_t = a + b_t;
		end
	end

	
	always @ (*) begin	
		if (result_t[16] == 1'b1 && operation == 1'b0) begin
			result = 16'h7000;
		end
		else if (result_t[16] == 1'b1 && operation == 1'b1) begin
			result = 16'h8000;
		end
		else begin
			result = result_t[15:0];
		end
	end
	// Pipeline Registers
	//reg [79:0] pipe_1;							// Pipeline register PreAlign->Align1
	
	
endmodule
*/

//============================================================================
// Comparator module
//============================================================================


module comparator(
a,
b,
aeb,
aneb,
alb,
aleb,
agb,
ageb,
unordered
);

input [15:0] a;
input [15:0] b;
output aeb;
output aneb;
output alb;
output aleb;
output agb;
output ageb;
output unordered;

  

reg lt;
reg eq;
reg gt;

wire [15:0] a_t;
wire [15:0] b_t;

assign a_t = (~a[15:0])+1;
assign b_t = (~b[15:0])+1;

always @(*) begin
	if (a[15] == 1'b0 && b[15] == 1'b1) begin
		if (a != b) begin
		eq = 1'b0;
		lt = 1'b0;
		gt = 1'b1;
		end
		else begin
		eq = 1'b1;
		lt = 1'b0;
		gt = 1'b0;
		end
	end
	else if (a[15] == 1'b1 && b[15] == 1'b0) begin
		if (a != b) begin
		lt = 1'b1;
		gt = 1'b0;
		eq = 1'b0;
		end
		else begin
		lt = 1'b0;
		gt = 1'b0;
		eq = 1'b1;
		end
	end
	else if (a[15] == 1'b0 && b[15] == 1'b0) begin
		if (a > b) begin
		lt = 1'b0;
		gt = 1'b1;
		eq = 1'b0;
		end
		else if (a < b) begin
		lt = 1'b1;
		gt = 1'b0;
		eq = 1'b0;
		end
		else begin
		lt = 1'b0;
		gt = 1'b0;
		eq = 1'b1;
		end
	end
	else if (a[15] == 1'b1 && b[15] == 1'b1) begin
		if (a_t > b_t) begin
		lt = 1'b1;
		gt = 1'b0;
		eq = 1'b0;
		end
		else if (a_t < b_t) begin
		lt = 1'b0;
		gt = 1'b1;
		eq = 1'b0;
		end
		else begin
		lt = 1'b0;
		gt = 1'b0;
		eq = 1'b1;
		end
	end
end


//Result flags
assign aeb = eq;
assign aneb = ~eq;
assign alb = lt;
assign aleb = lt | eq;
assign agb = gt;
assign ageb = gt | eq;

endmodule



//////////////////////////////////////////////////////
// Log unit
//////////////////////////////////////////////////////


module logunit (fpin, fpout, status, clk, reset, mode5_stage3_run, mode5_stage2_run, mode5_stage1_run);

	input [15:0] fpin;
	output [15:0] fpout;
	output [7:0] status;
	input clk,reset;

	input mode5_stage3_run;
    input mode5_stage2_run;
    input mode5_stage1_run;	
   // input mode5_stage0_run;
  
	wire [15: 0] fxout1;
	wire [15: 0] fxout2;
    wire [15:0] fpin_f;
    wire [15:0] fpout_f;
	reg [15:0] fpin_f_reg;
    reg [15:0] fpout_f_reg;
	reg [15: 0] fxout1_reg;
	reg [15: 0] fxout2_reg;
	//reg [15: 0] pipe1;
	//reg [15: 0] pipe2;

  int_to_float_fp16 int_float (.input_a(fpin),.output_z(fpin_f));
  FPLUT1 lut1 (.addr(fpin_f_reg[14:10]),.log(fxout1)); 
  FP8LUT2 lut2 (.addr(fpin_f_reg[9:2]),.log(fxout2)); 
  //adder_fp u_add(.a(fxout1_reg), .b(fxout2_reg),.out(fpout_f));
  DW_fp_addsub #(`MANTISSA, `EXPONENT, `IEEE_COMPLIANCE) add(.a(fxout1_reg), .b(fxout2_reg), .rnd(3'b0), .op(1'b0), .z(fpout_f), .status(status[7:0]));
  //DW_fp_add u_add(.a(fxout1_reg), .b(fxout2_reg),.out(fpout_f));

  //float_to_int_fp16 float_int (.input_a(fpout_f_reg),.output_z(fpout));
  float16_to_fixed16  float_int1 (.float_in(fpout_f_reg),.fixed_out(fpout));

    always @(posedge clk) begin
	/*if (reset) begin
		fpin_f_reg <= 16'b0;
	end */
	//if (~reset && mode5_stage2_run) begin
	if (mode5_stage3_run) begin
		fpin_f_reg <= fpin_f;
	end
    end

    always @(posedge clk) begin
	/*if (reset) begin
		fpin_f_reg <= 16'b0;
	end */
	//if (~reset && mode5_stage2_run) begin
	if (mode5_stage2_run) begin
		fxout2_reg <= fxout2;
		fxout1_reg <= fxout1;		
	end
    end
  
    always @(posedge clk) begin
	/*if (reset) begin
		fpout_f_reg <= 16'b0;
	end */
	//if (~reset && mode5_stage1_run) begin
	if (mode5_stage1_run) begin
		fpout_f_reg <= fpout_f;
	end
    end
endmodule

module float_to_int_fp16(
        input_a,
        output_z);


  input     [15:0] input_a;
  output    [15:0] output_z;

  
  wire [27:0] z;
  wire [5:0] a_e, sub_a_e;
  wire a_s;
  wire [15:0] a_m;
  wire [27:0] a_m_shift;  
  
  align_t dut_align (input_a,a_m,a_e,a_s);
  sub_t dut_sub (a_e,sub_a_e);
  am_shift_t dut_am_shift (a_e,sub_a_e,a_m,a_m_shift);
  two_comp_t dut_two_comp (a_m_shift,a_s,z);
  final_out_t dut_final_out (z, a_e, output_z);
  
endmodule

module align_t (
  input [15:0] input_a,
  output [15:0] a_m,
  output [5:0] a_e,
  output a_s);

  wire [15:0] a;

  assign a = input_a;
  assign a_m[15:5] = {1'b1, a[9 : 0]};
  assign a_m[4:0] = 8'b0;
  assign a_e = a[14 : 10] - 15;
  assign a_s = a[15];

endmodule

module sub_t (
  input [5:0] a_e,
  output [5:0] sub_a_e);

assign sub_a_e = 15 - a_e;

endmodule

module am_shift_t (
  input [5:0] a_e,
  input [5:0] sub_a_e,
  input [15:0] a_m,
  output reg [27:0] a_m_shift);

always@(a_e or sub_a_e or a_m) begin
  if (a_e <= 15 && a_e >= 0 ) begin
    a_m_shift = {a_m,12'b0} >> sub_a_e;
	end
	else begin
		a_m_shift = 24'h0;
	end
  end
  
endmodule

module two_comp_t (
  input [27:0] a_m_shift,
  input a_s,
  output [27:0] z);

assign z = a_s ? -a_m_shift : a_m_shift; // 2's complement

endmodule

module final_out_t (
  input [27:0] z,
  input [5:0] a_e,
  output [15:0] output_z);
  
  reg [27:0] output_z_temp;

always@(a_e or z) begin
  if (a_e[5] == 1'b1 && a_e[4:0] == 5'd15) begin
		output_z_temp = 27'b0;
	end
  else if (a_e[5] == 0 && a_e[4:0] > 5'd15) begin
		output_z_temp = 27'hFFFF;
	end
	else begin
		output_z_temp = z << 12;
	end
  end
  assign output_z = output_z_temp[27:12];
endmodule

module int_to_float_fp16(
        input_a,
        output_z);


  input     [15:0] input_a;
  output    [15:0] output_z;

  
  wire [15:0] value;
  wire z_s;
  wire [4:0] tmp_cnt;
  wire [4:0] sub_a_e;
  wire [4:0] sub_z_e;
  wire [15:0] a_m_shift;
  wire [10:0] z_m_final;
  wire [4:0] z_e_final;
  //wire [31:0] z;
  
  align dut_align (input_a,value,z_s);
  lzc dut_lzc (value,tmp_cnt);
  sub dut_sub (tmp_cnt,sub_a_e);
  sub2 dut_sub2 (sub_a_e,sub_z_e);
  am_shift dut_am_shift (value,sub_a_e,a_m_shift);
  exception dut_exception (a_m_shift,sub_z_e,z_m_final,z_e_final);
  final_out dut_final_out (input_a,z_m_final,z_e_final,z_s,output_z);

  
endmodule

module align (
  input [15:0] a,
  output [15:0] value,
output z_s);


  assign value = a[15] ? -a : a;
  assign z_s = a[15];

endmodule

/*module align2 (
input [31:0] value,
output [31:0] z_m,
//output [7:0] z_r,
//output [7:0] z_e);


	//z_e <= 8'd31;
    z_m <= value[31:0];
    //z_r <= value[7:0];

endmodule*/

module lzc (
  input [15:0] z_m,
  output reg [4:0] tmp_cnt_final);

  wire [15:0] Sj_int;
  //wire [15:0] val32;
wire [7:0] val8;
wire [3:0] val4;
  wire [4:0] tmp_cnt;

assign Sj_int = z_m;
  
assign    tmp_cnt[4] = 1'b0;
assign    tmp_cnt[3] = (Sj_int[15:8] == 8'b0);
assign    val8 = tmp_cnt[3] ? Sj_int[7:0] : Sj_int[15:8];
assign    tmp_cnt[2] = (val8[7:4] == 4'b0);
assign    val4 = tmp_cnt[2] ? val8[3:0] : val8[7:4];
assign    tmp_cnt[1] = (val4[3:2] == 2'b0);
assign    tmp_cnt[0] = tmp_cnt[1] ? ~val4[1] : ~val4[3];

always@(Sj_int or tmp_cnt)
begin
  if (Sj_int[15:0] == 16'b0)
   tmp_cnt_final = 5'd16;
else
   begin
   tmp_cnt_final = tmp_cnt;
end
end
endmodule

module sub (
  input [4:0] a_e,
  output [4:0] sub_a_e);

assign sub_a_e = a_e;

endmodule

module sub2 (
  input [4:0] a_e,
  output [4:0] sub_a_e);

assign sub_a_e = 15 - a_e;

endmodule

module am_shift (
  input [15:0] a_m,
  input [4:0] tmp_cnt,
  output [15:0] a_m_shift);

assign a_m_shift = a_m << tmp_cnt;  
endmodule

module exception (
  input [15:0] a_m_shift,
  input [4:0] z_e,
  output reg [10:0] z_m_final,
  output reg [4:0] z_e_final
);

wire guard;
wire round_bit;
wire sticky;
  wire [10:0] z_m;

  assign guard = a_m_shift[4];
  assign round_bit = a_m_shift[3];
  assign sticky = a_m_shift[2:0] != 0;

  assign z_m = a_m_shift[15:5];

always@(guard or round_bit or sticky or z_m or z_e)
begin
if (guard && (round_bit || sticky || z_m[0])) begin
    z_m_final = z_m + 1;
   if (z_m == 11'b11111111111) begin
            z_e_final = z_e + 1;
          end
		  else z_e_final = z_e;
          end
else begin 
  z_m_final = z_m;
  z_e_final = z_e;
end
end
endmodule

module final_out (
  input [15:0] a,
  input [10:0] z_m,
  input [4:0] z_e,
  input z_s,
  output reg [15:0] output_z);

  always@(a or z_m or z_e or z_s) begin
    if (a == 16'b0) begin
		output_z = 16'b0;
	end
	else begin
      output_z[9:0] = z_m[9:0];
      output_z[14:10] = z_e + 8'd3;
      output_z[15] = z_s;
	end
  end

endmodule

module FPLUT1(addr, log);
    input [4:0] addr;
    output reg [15:0] log;

    always @(addr) begin
        case (addr)
			5'b0 		: log = 16'b1111110000000000;
			5'b1 		: log = 16'b1100100011011010;
			5'b10 		: log = 16'b1100100010000001;
			5'b11 		: log = 16'b1100100000101001;
			5'b100 		: log = 16'b1100011110100000;
			5'b101 		: log = 16'b1100011011101110;
			5'b110 		: log = 16'b1100011000111101;
			5'b111 		: log = 16'b1100010110001100;
			5'b1000 		: log = 16'b1100010011011010;
			5'b1001 		: log = 16'b1100010000101001;
			5'b1010 		: log = 16'b1100001011101110;
			5'b1011 		: log = 16'b1100000110001100;
			5'b1100 		: log = 16'b1100000000101001;
			5'b1101 		: log = 16'b1011110110001100;
			5'b1110 		: log = 16'b1011100110001100;
			5'b1111 		: log = 16'b0000000000000000;
			5'b10000 		: log = 16'b0011100110001100;
			5'b10001 		: log = 16'b0011110110001100;
			5'b10010 		: log = 16'b0100000000101001;
			5'b10011 		: log = 16'b0100000110001100;
			5'b10100 		: log = 16'b0100001011101110;
			5'b10101 		: log = 16'b0100010000101001;
			5'b10110 		: log = 16'b0100010011011010;
			5'b10111 		: log = 16'b0100010110001100;
			5'b11000 		: log = 16'b0100011000111101;
			5'b11001 		: log = 16'b0100011011101110;
			5'b11010 		: log = 16'b0100011110100000;
			5'b11011 		: log = 16'b0100100000101001;
			5'b11100 		: log = 16'b0100100010000001;
			5'b11101 		: log = 16'b0100100011011010;
			5'b11110 		: log = 16'b0100100100110011;
			5'b11111 		: log = 16'b0111110000000000;
        endcase
    end
endmodule

module FP8LUT2(addr, log);
    input [7:0] addr;
    output reg [15:0] log;

    always @(addr) begin
        case (addr)
			8'b0 		: log = 16'b0000000000000000;
			8'b1 		: log = 16'b0001101111111100;
			8'b10 		: log = 16'b0001111111111000;
			8'b11 		: log = 16'b0010000111110111;
			8'b100 		: log = 16'b0010001111110000;
			8'b101 		: log = 16'b0010010011110100;
			8'b110 		: log = 16'b0010010111101110;
			8'b111 		: log = 16'b0010011011101000;
			8'b1000 		: log = 16'b0010011111100001;
			8'b1001 		: log = 16'b0010100001101100;
			8'b1010 		: log = 16'b0010100011101000;
			8'b1011 		: log = 16'b0010100101100011;
			8'b1100 		: log = 16'b0010100111011101;
			8'b1101 		: log = 16'b0010101001010111;
			8'b1110 		: log = 16'b0010101011010001;
			8'b1111 		: log = 16'b0010101101001010;
			8'b10000 		: log = 16'b0010101111000011;
			8'b10001 		: log = 16'b0010110000011101;
			8'b10010 		: log = 16'b0010110001011001;
			8'b10011 		: log = 16'b0010110010010101;
			8'b10100 		: log = 16'b0010110011010000;
			8'b10101 		: log = 16'b0010110100001100;
			8'b10110 		: log = 16'b0010110101000111;
			8'b10111 		: log = 16'b0010110110000010;
			8'b11000 		: log = 16'b0010110110111100;
			8'b11001 		: log = 16'b0010110111110111;
			8'b11010 		: log = 16'b0010111000110001;
			8'b11011 		: log = 16'b0010111001101011;
			8'b11100 		: log = 16'b0010111010100101;
			8'b11101 		: log = 16'b0010111011011110;
			8'b11110 		: log = 16'b0010111100011000;
			8'b11111 		: log = 16'b0010111101010001;
			8'b100000 		: log = 16'b0010111110001010;
			8'b100001 		: log = 16'b0010111111000011;
			8'b100010 		: log = 16'b0010111111111011;
			8'b100011 		: log = 16'b0011000000011010;
			8'b100100 		: log = 16'b0011000000110110;
			8'b100101 		: log = 16'b0011000001010010;
			8'b100110 		: log = 16'b0011000001101110;
			8'b100111 		: log = 16'b0011000010001010;
			8'b101000 		: log = 16'b0011000010100101;
			8'b101001 		: log = 16'b0011000011000001;
			8'b101010 		: log = 16'b0011000011011100;
			8'b101011 		: log = 16'b0011000011111000;
			8'b101100 		: log = 16'b0011000100010011;
			8'b101101 		: log = 16'b0011000100101111;
			8'b101110 		: log = 16'b0011000101001010;
			8'b101111 		: log = 16'b0011000101100101;
			8'b110000 		: log = 16'b0011000110000000;
			8'b110001 		: log = 16'b0011000110011011;
			8'b110010 		: log = 16'b0011000110110110;
			8'b110011 		: log = 16'b0011000111010000;
			8'b110100 		: log = 16'b0011000111101011;
			8'b110101 		: log = 16'b0011001000000101;
			8'b110110 		: log = 16'b0011001000100000;
			8'b110111 		: log = 16'b0011001000111010;
			8'b111000 		: log = 16'b0011001001010101;
			8'b111001 		: log = 16'b0011001001101111;
			8'b111010 		: log = 16'b0011001010001001;
			8'b111011 		: log = 16'b0011001010100011;
			8'b111100 		: log = 16'b0011001010111101;
			8'b111101 		: log = 16'b0011001011010111;
			8'b111110 		: log = 16'b0011001011110001;
			8'b111111 		: log = 16'b0011001100001010;
			8'b1000000 		: log = 16'b0011001100100100;
			8'b1000001 		: log = 16'b0011001100111110;
			8'b1000010 		: log = 16'b0011001101010111;
			8'b1000011 		: log = 16'b0011001101110000;
			8'b1000100 		: log = 16'b0011001110001010;
			8'b1000101 		: log = 16'b0011001110100011;
			8'b1000110 		: log = 16'b0011001110111100;
			8'b1000111 		: log = 16'b0011001111010101;
			8'b1001000 		: log = 16'b0011001111101110;
			8'b1001001 		: log = 16'b0011010000000100;
			8'b1001010 		: log = 16'b0011010000010000;
			8'b1001011 		: log = 16'b0011010000011100;
			8'b1001100 		: log = 16'b0011010000101001;
			8'b1001101 		: log = 16'b0011010000110101;
			8'b1001110 		: log = 16'b0011010001000001;
			8'b1001111 		: log = 16'b0011010001001110;
			8'b1010000 		: log = 16'b0011010001011010;
			8'b1010001 		: log = 16'b0011010001100110;
			8'b1010010 		: log = 16'b0011010001110010;
			8'b1010011 		: log = 16'b0011010001111110;
			8'b1010100 		: log = 16'b0011010010001010;
			8'b1010101 		: log = 16'b0011010010010110;
			8'b1010110 		: log = 16'b0011010010100010;
			8'b1010111 		: log = 16'b0011010010101110;
			8'b1011000 		: log = 16'b0011010010111010;
			8'b1011001 		: log = 16'b0011010011000110;
			8'b1011010 		: log = 16'b0011010011010010;
			8'b1011011 		: log = 16'b0011010011011110;
			8'b1011100 		: log = 16'b0011010011101010;
			8'b1011101 		: log = 16'b0011010011110101;
			8'b1011110 		: log = 16'b0011010100000001;
			8'b1011111 		: log = 16'b0011010100001101;
			8'b1100000 		: log = 16'b0011010100011000;
			8'b1100001 		: log = 16'b0011010100100100;
			8'b1100010 		: log = 16'b0011010100110000;
			8'b1100011 		: log = 16'b0011010100111011;
			8'b1100100 		: log = 16'b0011010101000111;
			8'b1100101 		: log = 16'b0011010101010010;
			8'b1100110 		: log = 16'b0011010101011110;
			8'b1100111 		: log = 16'b0011010101101001;
			8'b1101000 		: log = 16'b0011010101110100;
			8'b1101001 		: log = 16'b0011010110000000;
			8'b1101010 		: log = 16'b0011010110001011;
			8'b1101011 		: log = 16'b0011010110010110;
			8'b1101100 		: log = 16'b0011010110100010;
			8'b1101101 		: log = 16'b0011010110101101;
			8'b1101110 		: log = 16'b0011010110111000;
			8'b1101111 		: log = 16'b0011010111000011;
			8'b1110000 		: log = 16'b0011010111001110;
			8'b1110001 		: log = 16'b0011010111011010;
			8'b1110010 		: log = 16'b0011010111100101;
			8'b1110011 		: log = 16'b0011010111110000;
			8'b1110100 		: log = 16'b0011010111111011;
			8'b1110101 		: log = 16'b0011011000000110;
			8'b1110110 		: log = 16'b0011011000010001;
			8'b1110111 		: log = 16'b0011011000011100;
			8'b1111000 		: log = 16'b0011011000100111;
			8'b1111001 		: log = 16'b0011011000110001;
			8'b1111010 		: log = 16'b0011011000111100;
			8'b1111011 		: log = 16'b0011011001000111;
			8'b1111100 		: log = 16'b0011011001010010;
			8'b1111101 		: log = 16'b0011011001011101;
			8'b1111110 		: log = 16'b0011011001100111;
			8'b1111111 		: log = 16'b0011011001110010;
			8'b10000000 		: log = 16'b0011011001111101;
			8'b10000001 		: log = 16'b0011011010000111;
			8'b10000010 		: log = 16'b0011011010010010;
			8'b10000011 		: log = 16'b0011011010011101;
			8'b10000100 		: log = 16'b0011011010100111;
			8'b10000101 		: log = 16'b0011011010110010;
			8'b10000110 		: log = 16'b0011011010111100;
			8'b10000111 		: log = 16'b0011011011000111;
			8'b10001000 		: log = 16'b0011011011010001;
			8'b10001001 		: log = 16'b0011011011011100;
			8'b10001010 		: log = 16'b0011011011100110;
			8'b10001011 		: log = 16'b0011011011110000;
			8'b10001100 		: log = 16'b0011011011111011;
			8'b10001101 		: log = 16'b0011011100000101;
			8'b10001110 		: log = 16'b0011011100001111;
			8'b10001111 		: log = 16'b0011011100011010;
			8'b10010000 		: log = 16'b0011011100100100;
			8'b10010001 		: log = 16'b0011011100101110;
			8'b10010010 		: log = 16'b0011011100111000;
			8'b10010011 		: log = 16'b0011011101000011;
			8'b10010100 		: log = 16'b0011011101001101;
			8'b10010101 		: log = 16'b0011011101010111;
			8'b10010110 		: log = 16'b0011011101100001;
			8'b10010111 		: log = 16'b0011011101101011;
			8'b10011000 		: log = 16'b0011011101110101;
			8'b10011001 		: log = 16'b0011011101111111;
			8'b10011010 		: log = 16'b0011011110001001;
			8'b10011011 		: log = 16'b0011011110010011;
			8'b10011100 		: log = 16'b0011011110011101;
			8'b10011101 		: log = 16'b0011011110100111;
			8'b10011110 		: log = 16'b0011011110110001;
			8'b10011111 		: log = 16'b0011011110111011;
			8'b10100000 		: log = 16'b0011011111000101;
			8'b10100001 		: log = 16'b0011011111001110;
			8'b10100010 		: log = 16'b0011011111011000;
			8'b10100011 		: log = 16'b0011011111100010;
			8'b10100100 		: log = 16'b0011011111101100;
			8'b10100101 		: log = 16'b0011011111110110;
			8'b10100110 		: log = 16'b0011011111111111;
			8'b10100111 		: log = 16'b0011100000000100;
			8'b10101000 		: log = 16'b0011100000001001;
			8'b10101001 		: log = 16'b0011100000001110;
			8'b10101010 		: log = 16'b0011100000010011;
			8'b10101011 		: log = 16'b0011100000011000;
			8'b10101100 		: log = 16'b0011100000011101;
			8'b10101101 		: log = 16'b0011100000100001;
			8'b10101110 		: log = 16'b0011100000100110;
			8'b10101111 		: log = 16'b0011100000101011;
			8'b10110000 		: log = 16'b0011100000110000;
			8'b10110001 		: log = 16'b0011100000110100;
			8'b10110010 		: log = 16'b0011100000111001;
			8'b10110011 		: log = 16'b0011100000111110;
			8'b10110100 		: log = 16'b0011100001000010;
			8'b10110101 		: log = 16'b0011100001000111;
			8'b10110110 		: log = 16'b0011100001001100;
			8'b10110111 		: log = 16'b0011100001010001;
			8'b10111000 		: log = 16'b0011100001010101;
			8'b10111001 		: log = 16'b0011100001011010;
			8'b10111010 		: log = 16'b0011100001011110;
			8'b10111011 		: log = 16'b0011100001100011;
			8'b10111100 		: log = 16'b0011100001101000;
			8'b10111101 		: log = 16'b0011100001101100;
			8'b10111110 		: log = 16'b0011100001110001;
			8'b10111111 		: log = 16'b0011100001110110;
			8'b11000000 		: log = 16'b0011100001111010;
			8'b11000001 		: log = 16'b0011100001111111;
			8'b11000010 		: log = 16'b0011100010000011;
			8'b11000011 		: log = 16'b0011100010001000;
			8'b11000100 		: log = 16'b0011100010001100;
			8'b11000101 		: log = 16'b0011100010010001;
			8'b11000110 		: log = 16'b0011100010010101;
			8'b11000111 		: log = 16'b0011100010011010;
			8'b11001000 		: log = 16'b0011100010011110;
			8'b11001001 		: log = 16'b0011100010100011;
			8'b11001010 		: log = 16'b0011100010100111;
			8'b11001011 		: log = 16'b0011100010101100;
			8'b11001100 		: log = 16'b0011100010110000;
			8'b11001101 		: log = 16'b0011100010110101;
			8'b11001110 		: log = 16'b0011100010111001;
			8'b11001111 		: log = 16'b0011100010111110;
			8'b11010000 		: log = 16'b0011100011000010;
			8'b11010001 		: log = 16'b0011100011000110;
			8'b11010010 		: log = 16'b0011100011001011;
			8'b11010011 		: log = 16'b0011100011001111;
			8'b11010100 		: log = 16'b0011100011010100;
			8'b11010101 		: log = 16'b0011100011011000;
			8'b11010110 		: log = 16'b0011100011011100;
			8'b11010111 		: log = 16'b0011100011100001;
			8'b11011000 		: log = 16'b0011100011100101;
			8'b11011001 		: log = 16'b0011100011101001;
			8'b11011010 		: log = 16'b0011100011101110;
			8'b11011011 		: log = 16'b0011100011110010;
			8'b11011100 		: log = 16'b0011100011110110;
			8'b11011101 		: log = 16'b0011100011111011;
			8'b11011110 		: log = 16'b0011100011111111;
			8'b11011111 		: log = 16'b0011100100000011;
			8'b11100000 		: log = 16'b0011100100000111;
			8'b11100001 		: log = 16'b0011100100001100;
			8'b11100010 		: log = 16'b0011100100010000;
			8'b11100011 		: log = 16'b0011100100010100;
			8'b11100100 		: log = 16'b0011100100011000;
			8'b11100101 		: log = 16'b0011100100011101;
			8'b11100110 		: log = 16'b0011100100100001;
			8'b11100111 		: log = 16'b0011100100100101;
			8'b11101000 		: log = 16'b0011100100101001;
			8'b11101001 		: log = 16'b0011100100101101;
			8'b11101010 		: log = 16'b0011100100110010;
			8'b11101011 		: log = 16'b0011100100110110;
			8'b11101100 		: log = 16'b0011100100111010;
			8'b11101101 		: log = 16'b0011100100111110;
			8'b11101110 		: log = 16'b0011100101000010;
			8'b11101111 		: log = 16'b0011100101000110;
			8'b11110000 		: log = 16'b0011100101001011;
			8'b11110001 		: log = 16'b0011100101001111;
			8'b11110010 		: log = 16'b0011100101010011;
			8'b11110011 		: log = 16'b0011100101010111;
			8'b11110100 		: log = 16'b0011100101011011;
			8'b11110101 		: log = 16'b0011100101011111;
			8'b11110110 		: log = 16'b0011100101100011;
			8'b11110111 		: log = 16'b0011100101100111;
			8'b11111000 		: log = 16'b0011100101101011;
			8'b11111001 		: log = 16'b0011100101101111;
			8'b11111010 		: log = 16'b0011100101110011;
			8'b11111011 		: log = 16'b0011100101110111;
			8'b11111100 		: log = 16'b0011100101111100;
			8'b11111101 		: log = 16'b0011100110000000;
			8'b11111110 		: log = 16'b0011100110000100;
			8'b11111111 		: log = 16'b0011100110001000;
        endcase
    end
endmodule


//////////////////////////////////////////////////////
// Exponential unit
//////////////////////////////////////////////////////

module expunit (a, z, status, stage_run, stage_run2, clk, reset);

	input [15:0] a;
    input stage_run;
	input stage_run2;
    input clk;
    input reset;
    output reg [15:0] z;
    output [7:0] status;
	
    reg  [31:0] LUTout_reg;
	reg  [31:0] LUTout_reg2;
    reg  [15:0] a_reg;
	reg  [15:0] a_reg2;
	reg  [15:0] a_comp_reg;
	reg  [31:0] Mult_out_reg;
    wire [31:0] LUTout;
    wire [31:0] Mult_out;
    wire [15:0] a_comp;
    wire [15:0] z_out;
  	
    
	always @(posedge clk) begin
    if(reset) begin
      LUTout_reg2 <= 0;
	  a_reg2 <= 0;
	  a_comp_reg <= 0;
    end 
	else if(stage_run2) begin
      LUTout_reg2 <= LUTout;
	  a_reg2 <= a;
	  a_comp_reg <= a_comp;
    end
    end
	
	always @(posedge clk) begin
    if(reset) begin
      Mult_out_reg <= 0;
      LUTout_reg <= 0;
	  a_reg <= 0;
    end 
	else if(stage_run) begin
      Mult_out_reg <= Mult_out;
      LUTout_reg <= LUTout_reg2;
	  a_reg <= a_reg2;
    end
    end

    assign a_comp = ~a + 1'b1;
    ExpLUT lut(.addr(a_comp[14:8]), .exp(LUTout)); 
    assign Mult_out = ~(a_comp_reg*LUTout_reg2[31:16])+1;
    assign z_out = Mult_out_reg[27:12] + LUTout_reg[15:0];

    always@(z_out or a_reg) begin
      if (a_reg[15:12] == 4'b1000) begin
        //z = {12{1'b1}};
        z = 0;

      end
      else
        z = z_out;
    end
  
endmodule

module ExpLUT(addr, exp);
    input [6:0] addr;
    output reg [31:0] exp;

    always @(addr) begin
        case (addr)
	     7'b0000000            : exp =  32'b00001111100000100001000000000000;
	     7'b0000001            : exp =  32'b00001110100100100000111111110000;
	     7'b0000010            : exp =  32'b00001101101100000000111111010100;
	     7'b0000011            : exp =  32'b00001100110110110000111110101100;
	     7'b0000100            : exp =  32'b00001100000101000000111101111011;
	     7'b0000101            : exp =  32'b00001011010110000000111101000000;
	     7'b0000110            : exp =  32'b00001010101010000000111011111110;
	     7'b0000111            : exp =  32'b00001010000000110000111010110110;
	     7'b0001000            : exp =  32'b00001001011010000000111001101000;
	     7'b0001001            : exp =  32'b00001000110101100000111000010110;
	     7'b0001010            : exp =  32'b00001000010011010000110111000000;
	     7'b0001011            : exp =  32'b00000111110011000000110101101000;
	     7'b0001100            : exp =  32'b00000111010100110000110100001101;
	     7'b0001101            : exp =  32'b00000110111000010000110010110001;
	     7'b0001110            : exp =  32'b00000110011101110000110001010011;
	     7'b0001111            : exp =  32'b00000110000100100000101111110101;
	     7'b0010000            : exp =  32'b00000101101101000000101110010111;
	     7'b0010001            : exp =  32'b00000101010111000000101100111001;
	     7'b0010010            : exp =  32'b00000101000010010000101011011011;
	     7'b0010011            : exp =  32'b00000100101110100000101001111111;
	     7'b0010100            : exp =  32'b00000100011100010000101000100011;
	     7'b0010101            : exp =  32'b00000100001011000000100111001001;
	     7'b0010110            : exp =  32'b00000011111010110000100101110000;
	     7'b0010111            : exp =  32'b00000011101011110000100100011000;
	     7'b0011000            : exp =  32'b00000011011101010000100011000010;
	     7'b0011001            : exp =  32'b00000011010000000000100001101111;
	     7'b0011010            : exp =  32'b00000011000011010000100000011101;
	     7'b0011011            : exp =  32'b00000010110111100000011111001101;
	     7'b0011100            : exp =  32'b00000010101100010000011101111111;
	     7'b0011101            : exp =  32'b00000010100010000000011100110011;
	     7'b0011110            : exp =  32'b00000010011000000000011011101001;
	     7'b0011111            : exp =  32'b00000010001111000000011010100010;
	     7'b0100000            : exp =  32'b00000010000110010000011001011101;
	     7'b0100001            : exp =  32'b00000001111110000000011000011001;
	     7'b0100010            : exp =  32'b00000001110110100000010111011000;
	     7'b0100011            : exp =  32'b00000001101111010000010110011010;
	     7'b0100100            : exp =  32'b00000001101000100000010101011101;
	     7'b0100101            : exp =  32'b00000001100010010000010100100010;
	     7'b0100110            : exp =  32'b00000001011100010000010011101010;
	     7'b0100111            : exp =  32'b00000001010110100000010010110011;
	     7'b0101000            : exp =  32'b00000001010001010000010001111111;
	     7'b0101001            : exp =  32'b00000001001100100000010001001100;
	     7'b0101010            : exp =  32'b00000001000111110000010000011011;
	     7'b0101011            : exp =  32'b00000001000011100000001111101100;
	     7'b0101100            : exp =  32'b00000000111111010000001110111111;
	     7'b0101101            : exp =  32'b00000000111011100000001110010100;
	     7'b0101110            : exp =  32'b00000000111000000000001101101011;
	     7'b0101111            : exp =  32'b00000000110100100000001101000011;
	     7'b0110000            : exp =  32'b00000000110001010000001100011100;
	     7'b0110001            : exp =  32'b00000000101110010000001011111000;
	     7'b0110010            : exp =  32'b00000000101011100000001011010101;
	     7'b0110011            : exp =  32'b00000000101000110000001010110011;
	     7'b0110100            : exp =  32'b00000000100110010000001010010011;
	     7'b0110101            : exp =  32'b00000000100100000000001001110100;
	     7'b0110110            : exp =  32'b00000000100001110000001001010110;
	     7'b0110111            : exp =  32'b00000000011111110000001000111010;
	     7'b0111000            : exp =  32'b00000000011101110000001000011111;
	     7'b0111001            : exp =  32'b00000000011100000000001000000101;
	     7'b0111010            : exp =  32'b00000000011010010000000111101100;
	     7'b0111011            : exp =  32'b00000000011000110000000111010101;
	     7'b0111100            : exp =  32'b00000000010111010000000110111110;
	     7'b0111101            : exp =  32'b00000000010101110000000110101000;
	     7'b0111110            : exp =  32'b00000000010100100000000110010100;
	     7'b0111111            : exp =  32'b00000000010011010000000110000000;
	     7'b1000000            : exp =  32'b00000000010010000000000101101101;
	     7'b1000001            : exp =  32'b00000000010001000000000101011100;
	     7'b1000010            : exp =  32'b00000000010000000000000101001010;
	     7'b1000011            : exp =  32'b00000000001111000000000100111010;
	     7'b1000100            : exp =  32'b00000000001110000000000100101011;
	     7'b1000101            : exp =  32'b00000000001101010000000100011100;
	     7'b1000110            : exp =  32'b00000000001100010000000100001110;
	     7'b1000111            : exp =  32'b00000000001011100000000100000000;
	     7'b1001000            : exp =  32'b00000000001011000000000011110011;
	     7'b1001001            : exp =  32'b00000000001010010000000011100111;
	     7'b1001010            : exp =  32'b00000000001001100000000011011100;
	     7'b1001011            : exp =  32'b00000000001001000000000011010001;
	     7'b1001100            : exp =  32'b00000000001000100000000011000110;
	     7'b1001101            : exp =  32'b00000000001000000000000010111100;
	     7'b1001110            : exp =  32'b00000000000111100000000010110011;
	     7'b1001111            : exp =  32'b00000000000111000000000010101001;
	     7'b1010000            : exp =  32'b00000000000110100000000010100001;
	     7'b1010001            : exp =  32'b00000000000110010000000010011001;
	     7'b1010010            : exp =  32'b00000000000101110000000010010001;
	     7'b1010011            : exp =  32'b00000000000101100000000010001001;
	     7'b1010100            : exp =  32'b00000000000101000000000010000010;
	     7'b1010101            : exp =  32'b00000000000100110000000001111100;
	     7'b1010110            : exp =  32'b00000000000100100000000001110101;
	     7'b1010111            : exp =  32'b00000000000100010000000001101111;
	     7'b1011000            : exp =  32'b00000000000100000000000001101001;
	     7'b1011001            : exp =  32'b00000000000011110000000001100100;
	     7'b1011010            : exp =  32'b00000000000011100000000001011111;
	     7'b1011011            : exp =  32'b00000000000011010000000001011010;
	     7'b1011100            : exp =  32'b00000000000011000000000001010101;
	     7'b1011101            : exp =  32'b00000000000010110000000001010001;
	     7'b1011110            : exp =  32'b00000000000010110000000001001101;
	     7'b1011111            : exp =  32'b00000000000010100000000001001001;
	     7'b1100000            : exp =  32'b00000000000010010000000001000101;
	     7'b1100001            : exp =  32'b00000000000010010000000001000001;
	     7'b1100010            : exp =  32'b00000000000010000000000000111110;
	     7'b1100011            : exp =  32'b00000000000010000000000000111010;
	     7'b1100100            : exp =  32'b00000000000001110000000000110111;
	     7'b1100101            : exp =  32'b00000000000001110000000000110100;
	     7'b1100110            : exp =  32'b00000000000001100000000000110010;
	     7'b1100111            : exp =  32'b00000000000001100000000000101111;
	     7'b1101000            : exp =  32'b00000000000001010000000000101100;
	     7'b1101001            : exp =  32'b00000000000001010000000000101010;
	     7'b1101010            : exp =  32'b00000000000001010000000000101000;
	     7'b1101011            : exp =  32'b00000000000001000000000000100110;
	     7'b1101100            : exp =  32'b00000000000001000000000000100100;
	     7'b1101101            : exp =  32'b00000000000001000000000000100010;
	     7'b1101110            : exp =  32'b00000000000001000000000000100000;
	     7'b1101111            : exp =  32'b00000000000000110000000000011110;
	     7'b1110000            : exp =  32'b00000000000000110000000000011101;
	     7'b1110001            : exp =  32'b00000000000000110000000000011011;
	     7'b1110010            : exp =  32'b00000000000000110000000000011010;
	     7'b1110011            : exp =  32'b00000000000000110000000000011000;
	     7'b1110100            : exp =  32'b00000000000000100000000000010111;
	     7'b1110101            : exp =  32'b00000000000000100000000000010110;
	     7'b1110110            : exp =  32'b00000000000000100000000000010100;
	     7'b1110111            : exp =  32'b00000000000000100000000000010011;
	     7'b1111000            : exp =  32'b00000000000000100000000000010010;
	     7'b1111001            : exp =  32'b00000000000000100000000000010001;
	     7'b1111010            : exp =  32'b00000000000000010000000000010000;
	     7'b1111011            : exp =  32'b00000000000000010000000000001111;
	     7'b1111100            : exp =  32'b00000000000000010000000000001111;
	     7'b1111101            : exp =  32'b00000000000000010000000000001110;
	     7'b1111110            : exp =  32'b00000000000000010000000000001101;
	     7'b1111111            : exp =  32'b00000000000000010000000000001100;
        endcase
    end
endmodule
module float16_to_fixed16 (
    input  [15:0] float_in,     // 16-bit floating-point input
    output reg [15:0] fixed_out // 16-bit signed fixed-point output
);

    // Floating-point fields
    wire sign;                  // Sign bit
    wire [4:0] exponent;        // Exponent
    wire [10:0] mantissa;       // Mantissa (with implicit leading 1)

    // Internal variables
    reg [15:0] scaled_value;    // Scaled value for fixed-point
    reg [4:0] shift_amount;     // Amount to shift the mantissa
    reg [32:0] aligned_mantissa; // Extended mantissa for shifting

    // Extract fields from the floating-point input
    assign sign = float_in[15];
    assign exponent = float_in[14:10];
    assign mantissa = {1'b1, float_in[9:0]}; // Add implicit leading 1

    // Conversion logic
    always @(*) begin
        // Default output
        fixed_out = 16'b0;

        // Handle special cases
        if (exponent == 5'b00000) begin
            // Subnormal or zero case
            fixed_out = 16'b0;
        end else if (exponent == 5'b11111) begin
            // NaN or infinity, saturate to maximum value
            fixed_out = (sign) ? 16'h8000 : 16'h7FFF; // Max negative or positive
        end else begin
            // Normalized floating-point number
            // Calculate shift amount: actual exponent = exponent - bias (15)
           // if (exponent >= 15) begin
                shift_amount = exponent + 1; // Positive shift
                aligned_mantissa = mantissa << shift_amount; // Scale up
           // end else begin
          //      shift_amount = 15 - exponent; // Negative shift
           //     aligned_mantissa = mantissa >> shift_amount; // Scale down

            // Scale down the mantissa for Q3.13 format
            scaled_value = aligned_mantissa[29:14]; // Truncate to 16 bits (Q3.13)
            
            // Apply the sign bit
            if (sign) begin
                fixed_out = ~scaled_value + 1; // Two's complement for negative numbers
            end else begin
                fixed_out = scaled_value;
            end
        end
    end

endmodule
module  fixed_point_addsub(
input		clk,
input		rst,
    input  [15:0] a,          // First 16-bit signed fixed-point input
    input  [15:0] b,          // Second 16-bit signed fixed-point input
    input         operation,  // Operation selector: 0 = Add, 1 = Subtract
    output reg [15:0] result, // 16-bit signed fixed-point result
    output reg overflow,       // Overflow flag
	output [4:0] flags							// Flags indicating exceptions according to IEEE754
);

    // Intermediate variables
    reg [16:0] result_extended; // Extended width for intermediate computation
    reg [15:0] b_t;             // Negated version of b for subtraction

    always @(*) begin
        // Default outputs
        overflow = 0;
        result = 0;

        // Negate b if performing subtraction
        b_t = (operation == 1'b1) ? (~b + 1'b1) : b;

        // Perform addition with extended precision
        result_extended = {a[15], a} + {b_t[15], b_t};

        // Check for overflow: Signed overflow occurs if sign bits mismatch
        if ((a[15] == b_t[15]) && (result_extended[15] != result_extended[16])) begin
            overflow = 1;
            // Saturate result on overflow
            result = (result_extended[16]) ? 16'h8000 : 16'h7FFF; // Min/Max signed value
        end else begin
            // Truncate to 16 bits if no overflow
            result = result_extended[15:0];
        end
    end

endmodule

