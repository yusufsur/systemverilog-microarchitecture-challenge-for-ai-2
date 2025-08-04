
///////////////////////////////////////////
// fmtparams.sv
//
// Written: David_Harris@hmc.edu
// Modified: 5/11/24
//
// Purpose: Look up bias of exponent and number of fractional bits for the selected format
//
// Documentation: RISC-V System on Chip Design
//
// A component of the CORE-V-WALLY configurable RISC-V project.
// https://github.com/openhwgroup/cvw
//
// Copyright (C) 2021-23 Harvey Mudd College & Oklahoma State University
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
// except in compliance with the License, or, at your option, the Apache License version 2.0. You
// may obtain a copy of the License at
//
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the
// License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific language governing permissions
// and limitations under the License.
////////////////////////////////////////////////////////////////////////////////////////////////

module fmtparams (
  input  logic [  FMTBITS-1:0] Fmt,
  output logic [  NE-2:0]      Bias,
  output logic [  LOGFLEN-1:0] Nf
);

  if (  FPSIZES == 1) begin
    assign Bias = (  NE-1)'(  BIAS);
  end else if (  FPSIZES == 2) begin
    assign Bias = Fmt ? (  NE-1)'(  BIAS) : (  NE-1)'(  BIAS1);
  end else if (  FPSIZES == 3) begin
    always_comb
      case (Fmt)
          FMT:  Bias =  (  NE-1)'(  BIAS);
          FMT1: Bias = (  NE-1)'(  BIAS1);
          FMT2: Bias = (  NE-1)'(  BIAS2);
        default: Bias = 'x;
      endcase
  end else if (  FPSIZES == 4) begin
    always_comb
      case (Fmt)
        2'h3: Bias =  (  NE-1)'(  Q_BIAS);
        2'h1: Bias =  (  NE-1)'(  D_BIAS);
        2'h0: Bias =  (  NE-1)'(  S_BIAS);
        2'h2: Bias =  (  NE-1)'(  H_BIAS);
      endcase
  end

  /* verilator lint_off WIDTH */
  if (  FPSIZES == 1)
    assign Nf =   NF;
  else if (  FPSIZES == 2)
    always_comb
      case (Fmt)
        1'b0: Nf =   NF1;
        1'b1: Nf =   NF;
      endcase
  else if (  FPSIZES == 3)
    always_comb
      case (Fmt)
          FMT:   Nf =   NF;
          FMT1:  Nf =   NF1;
          FMT2:  Nf =   NF2;
        default: Nf = 'x; // shouldn't happen
      endcase
  else if (  FPSIZES == 4)
    always_comb
      case(Fmt)
          S_FMT: Nf =   S_NF;
          D_FMT: Nf =   D_NF;
          H_FMT: Nf =   H_NF;
          Q_FMT: Nf =   Q_NF;
      endcase
  /* verilator lint_on WIDTH */

endmodule
