///////////////////////////////////////////
// fmashiftcalc.sv
//
// Written: me@KatherineParry.com
// Modified: 7/5/2022
//
// Purpose: FMA shift calculation
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

module fmashiftcalc (
  input  logic [  FMTBITS-1:0]          Fmt,                 // precision 1 = double 0 = single
  input  logic [  NE+1:0]               FmaSe,               // sum's exponent
  input  logic [  FMALEN-1:0]           FmaSm,               // the positive sum
  input  logic [$clog2(  FMALEN+1)-1:0] FmaSCnt,             // normalization shift count
  output logic [  NE+1:0]               NormSumExp,          // exponent of the normalized sum not taking into account Subnormal or zero results
  output logic                          FmaSZero,            // is the sum zero
  output logic                          FmaPreResultSubnorm, // is the result subnormal - calculated before LZA correction
  output logic [$clog2(  FMALEN+1)-1:0] FmaShiftAmt          // normalization shift count
);
  logic [  NE+1:0]                      PreNormSumExp;       // the exponent of the normalized sum with the   FLEN bias
  logic [  NE+1:0]                      BiasCorr;            // correction for bias

  ///////////////////////////////////////////////////////////////////////////////
  // Normalization
  ///////////////////////////////////////////////////////////////////////////////

  // Determine if the sum is zero
  assign FmaSZero = ~(|FmaSm);

  // calculate the sum's exponent FmaSe-FmaSCnt+NF+2
  assign PreNormSumExp = FmaSe + {{  NE+2-$unsigned($clog2(  FMALEN+1)){1'b1}}, ~FmaSCnt} + (  NE+2)'(  NF+4);

  //convert the sum's exponent into the proper precision
  if (  FPSIZES == 1) begin
    assign NormSumExp = PreNormSumExp;
    assign BiasCorr = '0;
  end else if (  FPSIZES == 2) begin
    assign BiasCorr = Fmt ? (  NE+2)'(0) : (  NE+2)'(  BIAS1-  BIAS);
    assign NormSumExp = PreNormSumExp+BiasCorr;
  end else if (  FPSIZES == 3) begin
    always_comb begin
        case (Fmt)
              FMT:   BiasCorr =  '0;
              FMT1:  BiasCorr = (  NE+2)'(  BIAS1-  BIAS);
              FMT2:  BiasCorr = (  NE+2)'(  BIAS2-  BIAS);
            default: BiasCorr = 'x;
        endcase
    end
    assign NormSumExp = PreNormSumExp+BiasCorr;
  end else if (  FPSIZES == 4) begin
    always_comb begin
        case (Fmt)
            2'h3: BiasCorr = '0;
            2'h1: BiasCorr = (  NE+2)'(  D_BIAS-  Q_BIAS);
            2'h0: BiasCorr = (  NE+2)'(  S_BIAS-  Q_BIAS);
            2'h2: BiasCorr = (  NE+2)'(  H_BIAS-  Q_BIAS);
        endcase
    end
    assign NormSumExp = PreNormSumExp+BiasCorr;
  end

  // determine if the result is subnormal: (NormSumExp <= 0) & (NormSumExp >= -FracLen)
  if (  FPSIZES == 1) begin
    logic Sum0LEZ, Sum0GEFL;
    assign Sum0LEZ  = PreNormSumExp[  NE+1] | ~|PreNormSumExp;
    assign Sum0GEFL = $signed(PreNormSumExp) >= $signed((  NE+2)'(-  NF-1)); // changed from -2 dh 4/3/24 for issue 655
    assign FmaPreResultSubnorm = Sum0LEZ & Sum0GEFL;
  end else if (  FPSIZES == 2) begin
    logic Sum0LEZ, Sum0GEFL, Sum1LEZ, Sum1GEFL;
    assign Sum0LEZ  = PreNormSumExp[  NE+1] | ~|PreNormSumExp;
    assign Sum0GEFL = $signed(PreNormSumExp) >= $signed((  NE+2)'(-  NF-1)); // changed from -2 dh 4/3/24 for issue 655
    assign Sum1LEZ  = $signed(PreNormSumExp) <= $signed((  NE+2)'(  BIAS-  BIAS1));
    assign Sum1GEFL = $signed(PreNormSumExp) >= $signed((  NE+2)'(-  NF1-1+  BIAS-  BIAS1)) | ~|PreNormSumExp;
    assign FmaPreResultSubnorm = (Fmt ? Sum0LEZ : Sum1LEZ) & (Fmt ? Sum0GEFL : Sum1GEFL);
  end else if (  FPSIZES == 3) begin
    logic Sum0LEZ, Sum0GEFL, Sum1LEZ, Sum1GEFL, Sum2LEZ, Sum2GEFL;
    assign Sum0LEZ  = PreNormSumExp[  NE+1] | ~|PreNormSumExp;
    assign Sum0GEFL = $signed(PreNormSumExp) >= $signed((  NE+2)'(-  NF-1));
    assign Sum1LEZ  = $signed(PreNormSumExp) <= $signed((  NE+2)'(  BIAS-  BIAS1));
    assign Sum1GEFL = $signed(PreNormSumExp) >= $signed((  NE+2)'(-  NF1-1+  BIAS-  BIAS1)) | ~|PreNormSumExp;
    assign Sum2LEZ  = $signed(PreNormSumExp) <= $signed((  NE+2)'(  BIAS-  BIAS2));
    assign Sum2GEFL = $signed(PreNormSumExp) >= $signed((  NE+2)'(-  NF2-1+  BIAS-  BIAS2)) | ~|PreNormSumExp;
    always_comb begin
      case (Fmt)
          FMT: FmaPreResultSubnorm   = Sum0LEZ & Sum0GEFL;
          FMT1: FmaPreResultSubnorm  = Sum1LEZ & Sum1GEFL;
          FMT2: FmaPreResultSubnorm  = Sum2LEZ & Sum2GEFL;
        default: FmaPreResultSubnorm = 1'bx;
      endcase
    end
  end else if (  FPSIZES == 4) begin
    logic Sum0LEZ, Sum0GEFL, Sum1LEZ, Sum1GEFL, Sum2LEZ, Sum2GEFL, Sum3LEZ, Sum3GEFL;
    assign Sum0LEZ  = PreNormSumExp[  NE+1] | ~|PreNormSumExp;
    assign Sum0GEFL = $signed(PreNormSumExp) >= $signed((  NE+2)'(-  NF-1));
    assign Sum1LEZ  = $signed(PreNormSumExp) <= $signed((  NE+2)'(  BIAS-  D_BIAS));
    assign Sum1GEFL = $signed(PreNormSumExp) >= $signed((  NE+2)'(-  D_NF-1+  BIAS-  D_BIAS)) | ~|PreNormSumExp;
    assign Sum2LEZ  = $signed(PreNormSumExp) <= $signed((  NE+2)'(  BIAS-  S_BIAS));
    assign Sum2GEFL = $signed(PreNormSumExp) >= $signed((  NE+2)'(-  S_NF-1+  BIAS-  S_BIAS)) | ~|PreNormSumExp;
    assign Sum3LEZ  = $signed(PreNormSumExp) <= $signed((  NE+2)'(  BIAS-  H_BIAS));
    assign Sum3GEFL = $signed(PreNormSumExp) >= $signed((  NE+2)'(-  H_NF-1+  BIAS-  H_BIAS)) | ~|PreNormSumExp;
    always_comb begin
      case (Fmt)
        2'h3: FmaPreResultSubnorm = Sum0LEZ & Sum0GEFL;
        2'h1: FmaPreResultSubnorm = Sum1LEZ & Sum1GEFL;
        2'h0: FmaPreResultSubnorm = Sum2LEZ & Sum2GEFL;
        2'h2: FmaPreResultSubnorm = Sum3LEZ & Sum3GEFL;
      endcase
    end
  end

  // set and calculate the shift input and amount
  //  - shift once if killing a product and the result is subnormal
  assign FmaShiftAmt = FmaPreResultSubnorm ? FmaSe[$clog2(  FMALEN-1)-1:0]+($clog2(  FMALEN-1))'(  NF+3)+BiasCorr[$clog2(  FMALEN-1)-1:0]: FmaSCnt+1;
endmodule
