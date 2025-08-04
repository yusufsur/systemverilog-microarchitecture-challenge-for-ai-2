
///////////////////////////////////////////
// packoutput.sv
//
// Written: David_Harris@hmc.edu
// Modified: 5/11/24
//
// Purpose: Pack the output of the FPU
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

module packoutput (
  input  logic [  FLEN-1:0]       Unpacked,
  input  logic [  FMTBITS-1:0]    Fmt,
  output logic [  FLEN-1:0]       Packed
);

  logic             Sign;
  logic [  NE1-1:0] Exp1;
  logic [  NF1-1:0] Fract1;
  logic [  NE2-1:0] Exp2;
  logic [  NF2-1:0] Fract2;
  logic [  H_NE-1:0] Exp3;
  logic [  H_NF-1:0] Fract3;

  // Pack exponent and fraction, with NaN-boxing to full FLEN

  assign Sign = Unpacked[  FLEN-1];
  if (  FPSIZES == 1) begin
    assign Packed = Unpacked;
  end else if (  FPSIZES == 2) begin
    always_comb begin
      {Exp1, Fract1} = '0; // default if not used, to prevent latch
      case (Fmt)
        1'b1: Packed = Unpacked;
        1'b0: begin
                Exp1 = {Unpacked[  FLEN-2], Unpacked[  NF+  NE1-2:  NF]};
                Fract1 = Unpacked[  NF-1:  NF-  NF1];
                Packed = {{(  FLEN-  LEN1){1'b1}}, Sign, Exp1, Fract1};
              end
      endcase
    end
  end else if (  FPSIZES == 3) begin
    always_comb begin
      {Exp1, Fract1, Exp2, Fract2} = '0; // default if not used, to prevent latch
      case (Fmt)
          FMT: Packed = Unpacked;
          FMT1: begin
                Exp1 = {Unpacked[  FLEN-2], Unpacked[  NF+  NE1-2:  NF]};
                Fract1 = Unpacked[  NF-1:  NF-  NF1];
                Packed = {{(  FLEN-  LEN1){1'b1}}, Sign, Exp1, Fract1};
              end
          FMT2: begin
                Exp2 = {Unpacked[  FLEN-2], Unpacked[  NF+  NE2-2:  NF]};
                Fract2 = Unpacked[  NF-1:  NF-  NF2];
                Packed = {{(  FLEN-  LEN2){1'b1}}, Sign, Exp2, Fract2};
              end
        default: Packed = 'x;
      endcase
    end
  end else if (  FPSIZES == 4) begin
    always_comb begin
      {Exp1, Fract1, Exp2, Fract2, Exp3, Fract3} = '0; // default if not used, to prevent latch
      case (Fmt)
        2'h3: Packed = Unpacked;  // Quad
        2'h1: begin // double
                Exp1 = {Unpacked[  FLEN-2], Unpacked[  NF+  NE1-2:  NF]};
                Fract1 = Unpacked[  NF-1:  NF-  NF1];
                Packed = {{(  FLEN-  LEN1){1'b1}}, Sign, Exp1, Fract1};
              end
        2'h0: begin // float
                Exp2 = {Unpacked[  FLEN-2], Unpacked[  NF+  NE2-2:  NF]};
                Fract2 = Unpacked[  NF-1:  NF-  NF2];
                Packed = {{(  FLEN-  LEN2){1'b1}}, Sign, Exp2, Fract2};
              end
        2'h2: begin // half
                Exp3 = {Unpacked[  FLEN-2], Unpacked[  NF+  H_NE-2:  NF]};
                Fract3 = Unpacked[  NF-1:  NF-  H_NF];
                Packed = {{(  FLEN-  H_LEN){1'b1}}, Sign, Exp3, Fract3};
              end
      endcase
    end
  end
endmodule
