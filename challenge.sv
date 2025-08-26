/*
 
Put any submodules you need here.
 
You are not allowed to implement your own submodules or functions for the addition,
subtraction, multiplication, division, comparison or getting the square
root of floating-point numbers. For such operations you can only use the
modules from the arithmetic_block_wrappers directory.
 
*/

module challenge
  (
    input                     clk,
    input                     rst,

    input                     arg_vld,
    output                    arg_rdy,
    input        [FLEN - 1:0] a,
    input        [FLEN - 1:0] b,
    input        [FLEN - 1:0] c,

    output logic              res_vld,
    input  logic              res_rdy,
    output logic [FLEN - 1:0] res
  );
  /*

  The Prompt:

  Finish the code of a pipelined block in the file challenge.sv. The block
  computes a formula "a ** 5 + 0.3 * b - c". Ready/valid handshakes for
  the arguments and the result follow the same rules as ready/valid in AXI
  Stream. When a block is not busy, arg_rdy should be 1, it should not
  wait for arg_vld. You are not allowed to implement your own submodules
  or functions for the addition, subtraction, multiplication, division,
  comparison or getting the square root of floating-point numbers. For
  such operations you can only use the modules from the
  arithmetic_block_wrappers directory. You are not allowed to change any
  other files except challenge.sv. You can check the results by running
  the script "simulate". If the script outputs "FAIL" or does not output
  "PASS" from the code in the provided testbench.sv by running the
  provided script "simulate", your design is not working and is not an
  answer to the challenge. Your design must be able to accept a new set of
  the inputs (a, b and c) each clock cycle back-to-back and generate the
  computation results without any stalls and without requiring empty cycle
  gaps in the input. The solution code has to be synthesizable
  SystemVerilog RTL. A human should not help AI by tipping anything on
  latencies or handshakes of the submodules. The AI has to figure this out
  by itself by analyzing the code in the repository directories. Likewise
  a human should not instruct AI how to build a pipeline structure since
  it makes the exercise meaningless.

  */

  /***********************************************************************************************/
  /* A^5 block starts here */
  logic [FLEN-1:0] a2_result, a4_result;
  logic [FLEN-1:0] a2_result_stagepipe, a4_result_stagepipe;

  logic a2_valid, a4_valid, a5_valid;
  logic a2_valid_stagepipe, a4_valid_stagepipe;

  logic [FLEN-1:0] a_stage1, a_stage2;
  logic a_valid_stage1, a_valid_stage2;

  f_mult  f_mult_inst_a2 (
            .clk(clk),
            .rst(rst),
            .a(a),
            .b(a), //feed input a both for a^2
            .up_valid(arg_vld),
            .res(a2_result),
            .down_valid(a2_valid),
            .busy(busy_a2),
            .error(error_a2)
          );

  //stage the output of mults
  always_ff @(posedge clk or posedge rst)
  begin
    if (rst)
    begin
      a2_result_stagepipe <= 0;
      a2_valid_stagepipe <= 0;
    end
    else
    begin
      if (a2_valid)
      begin
        a2_result_stagepipe <= a2_result;
        a2_valid_stagepipe <= a2_valid;
      end
    end
  end

  f_mult  f_mult_inst_a4 (
            .clk(clk),
            .rst(rst),
            .a(a2_result_stagepipe),
            .b(a2_result_stagepipe), // feed the a^2 for finding a^4
            .up_valid(a2_valid_stagepipe),
            .res(a4_result),
            .down_valid(a4_valid),
            .busy(busy_a4),
            .error(error_a4)
          );

  always_ff @(posedge clk or posedge rst)
  begin
    if (rst)
    begin
      a4_result_stagepipe <= 0;
      a4_valid_stagepipe <= 0;
    end
    else
    begin
      if (a4_valid)
      begin
        a4_result_stagepipe <= a4_result;
        a4_valid_stagepipe <= a4_valid;
      end
    end
  end

  f_mult  f_mult_inst_a5 (
            .clk(clk),
            .rst(rst),
            .a(a_delayed), //delay the a to align the pipeline
            .b(a4_result_stagepipe),
            .up_valid(a4_valid_stagepipe && arg_vld_delayed),
            .res(a5_result), // a^4 * a = a^5
            .down_valid(a5_valid), //a^5 ready signal
            .busy(busy_a5),
            .error(error_a5)
          );

  logic [FLEN-1:0] a_todelay, a_delayed;
  logic arg_vld_delayed;
  localparam A_DELAY_PIPE = 2;
  localparam DELAY_MULTUNITS = 2;
  localparam A_DELAY_UNITAMOUNT; = 3;
  localparam A_DELAY = (DELAY_MULTUNITS*A_DELAY_UNITAMOUNT) +  A_DELAY_PIPE;

  assign a_todelay = arg_vld ? a : 0;

  /*delay a until a5 computation*/
  delay # (
          .DLY(A_DELAY),
          .DW(FLEN)
        )
        delay_inst_a (
          .clk(clk),
          .din(a_todelay),
          .dout(a_delayed)
        );

  /*delay a until a5 computation*/
  delay # (
          .DLY(A_DELAY),
          .DW(FLEN)
        )
        delay_inst_avalid (
          .clk(clk),
          .din(arg_vld),
          .dout(arg_vld_delayed)
        );

  /*A5 Block ends here*/

  /***********************************************************************************************/

  /* 0.3* B block start here*/

  localparam logic [FLEN-1:0] CONST_03 = 32'h3E99999A;
  logic 03b_valid, 03b_valid_stagepipe, busy_03b, error_03b;
  logic [FLEN-1:0] 03b_result, 03b_result_delay, 03b_result_delay_2, 03b_result_delay_3;

  f_mult  f_mult_inst_03xB (
            .clk(clk),
            .rst(rst),
            .a(CONST_03),
            .b(b),
            .up_valid(arg_vld),
            .res(03b_result),
            .down_valid(03b_valid),
            .busy(busy_03b),
            .error(error_03b)
          );

  logic [FLEN-1:0] 03b_result_todelay, 03b_result_delayed;
  logic 03b_valid_todelay, 03b_valid_delayed;

  assign 03b_result_todelay = 03b_valid ? 03b_result : 0;
  assign 03b_valid_todelay = 03b_valid;

  localparam 03B_DELAY = A_DELAY - DELAY_MULTUNITS;

  delay # (
          .DLY(03B_DELAY),
          .DW(FLEN)
        )
        delay_inst_03bresult (
          .clk(clk),
          .din(03b_result_todelay),
          .dout(03b_result_delayed)
        );

  delay # (
          .DLY(03B_DELAY),
          .DW(FLEN)
        )
        delay_inst_03bvalid (
          .clk(clk),
          .din(03b_valid_todelay),
          .dout(03b_valid_delayed)
        );

  /* 0.3* B block ends here*/

  /***********************************************************************************************/
  logic [FLEN-1:0] 03b_result_2add, a5_result_2add, A5plus03B;
  logic 03b_valid_2add, a5_valid_2add;
  logic busy_A5plus03B, error_A5plus03B, A5plus03B_valid;

  always @(posedge clk or posedge rst)
  begin
    if (rst)
    begin

    end
    else
    begin
      if (03b_valid_delayed && a5_valid)
      begin
        a5_result_2add <= a5_result;
        a5_valid_2add  <= a5_valid;
        03b_result_2add <= 03b_result_delayed;
        03b_valid_2add <= 03b_valid_delayed;
      end
    end
  end
  /* A^5 + 0.3* B block starts here*/
  f_add  f_add_inst_a5_03b (
           .clk(clk),
           .rst(rst),
           .a(a5_result_2add),
           .b(03b_result_2add),
           .up_valid(a5_valid_2add && 03b_valid_2add ),
           .res(A5plus03B),
           .down_valid(A5plus03B_valid),
           .busy(busy_A5plus03B),
           .error(error_A5plus03B)
         );
  /* A^5 + 0.3* B block ends here*/

  /***********************************************************************************************/
  logic [FLEN-1:0] c_2delay, c_delayed;
  logic arg_vld_delayed;

  assign c_2delay = arg_vld ? c : 0;
  localparam DELAY_ADDUNITS = 1;
  /* C block starts here*/
  delay # (
          .DLY(A_DELAY + DELAY_ADDUNITS-1), //amount of A delay plus one add unit minus 1 since I reg it again below inside always 
          .DW(FLEN)
        )
        delay_inst_c (
          .clk(clk),
          .din(c_2delay),
          .dout(c_delayed)
        );

  delay # (
          .DLY(A_DELAY + DELAY_ADDUNITS-1), //amount of A delay plus one add unit minus 1 since I reg it again below inside always 
          .DW(1)
        )
        delay_inst_argvld (
          .clk(clk),
          .din(arg_vld),
          .dout(arg_vld_delayed)
        );
  /* C block ends here*/
  /***********************************************************************************************/
  /* Final block starts here*/
  logic [FLEN-1:0] A5plus03B_reg, c_delayed_reg, arg_vld_delayed_reg, final_result;
  logic final_result_valid;

  always @(posedge clk or negedge rst) begin
    if (rst) begin
      A5plus03B_reg <= 0;
      c_delayed_reg <= 0;
    end else begin
      A5plus03B_reg <= A5plus03B;
      c_delayed_reg <= c_delayed;
      arg_vld_delayed_reg <= arg_vld_delayed;
      A5plus03B_valid_reg <= A5plus03B_valid;
    end
  end
  f_add  f_add_inst_final (
           .clk(clk),
           .rst(rst),
           .a(A5plus03B_reg),
           .b(c_delayed_reg),
           .up_valid(arg_vld_delayed_reg && A5plus03B_valid_reg ),
           .res(final_result),
           .down_valid(final_result_valid),
           .busy(busy_final),
           .error(error_final)
         );
  /* Final block ends here*/

endmodule
