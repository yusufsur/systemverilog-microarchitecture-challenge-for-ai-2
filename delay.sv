module delay #(
    parameter DLY   = 1,
    parameter DW    = 1
)(
    input   clk,
    input   [DW-1:0]    din,
    output  [DW-1:0]    dout
);

    integer i;
    logic [DW-1:0] samp [0:DLY-1];

    assign dout = samp[DLY-1];

    always @(posedge clk) begin
        for(i=0; i<DLY; i=i+1) begin
            if(i==0)
                samp[0] <= din;
            else
                samp[i] <= samp[i-1];
        end
    end

endmodule