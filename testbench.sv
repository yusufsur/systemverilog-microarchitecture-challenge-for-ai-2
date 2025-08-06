//----------------------------------------------------------------------------
// Debug macros

`define PD(SYMBOL) $sformatf("SYMBOL:%0d" , SYMBOL)
`define PB(SYMBOL) $sformatf("SYMBOL:%b"  , SYMBOL)
`define PH(SYMBOL) $sformatf("SYMBOL:%h"  , SYMBOL)
`define PF(SYMBOL) $sformatf("SYMBOL:%f"  , SYMBOL)

`define PF_BITS(SYMBOL) $sformatf("SYMBOL:%f" , $bitstoreal (SYMBOL))
`define PG_BITS(SYMBOL) $sformatf("SYMBOL:%g" , $bitstoreal (SYMBOL))

//----------------------------------------------------------------------------

module testbench;

    //------------------------------------------------------------------------
    // Signals to drive Device Under Test - DUT

    logic               clk;
    logic               rst;

    logic               arg_vld;
    logic  [FLEN - 1:0] a;
    logic  [FLEN - 1:0] b;
    logic  [FLEN - 1:0] c;

    wire                res_vld;
    wire   [FLEN - 1:0] res;
    wire                res_negative;
    wire                err;

    wire                busy;

    //--------------------------------------------------------------------------

    // If we change FLEN to 32, we have to change these constants

    localparam [FLEN - 1:0] inf     = 64'h7FF0_0000_0000_0000,
                            neg_inf = 64'hFFF0_0000_0000_0000,
                            zero    = 64'h0000_0000_0000_0000,
                            nan     = 64'h7FF1_2345_6789_ABCD;

    //--------------------------------------------------------------------------
    // Instantiating DUT

    challenge dut (.*);

    //--------------------------------------------------------------------------
    // Driving clk

    initial
    begin
        clk = '1;

        forever
        begin
            # 5 clk = ~ clk;
        end
    end

    //------------------------------------------------------------------------
    // Reset

    task reset ();

        rst <= 'x;
        repeat (3) @ (posedge clk);
        rst <= '1;
        repeat (3) @ (posedge clk);
        rst <= '0;

    endtask

    //--------------------------------------------------------------------------
    // Test ID for error messages

    string test_id;

    initial $sformat (test_id, "%s", `__FILE__);

    //--------------------------------------------------------------------------
    // Utilities to drive stimulus

    localparam max_latency       = 16,
               gap_between_tests = 100;

    function int randomize_gap ();

        int gap_class;

        gap_class = $urandom_range (1, 100);

        if (gap_class <= 60)       // With a 60% probability: without gaps
            return 0;
        else if (gap_class <= 95)  // With a 35% probability: gap 1..3
            return $urandom_range (1, 3);
        else                       // With a  5% probability: gap 4..max_latency + 2
            return $urandom_range (4, max_latency + 2);

    endfunction

    //--------------------------------------------------------------------------

    task drive_arg_vld
    (
        bit random_gap = 0,
        int gap        = 0
    );

        arg_vld <= 1'b1;
        @ (posedge clk);
        arg_vld <= 1'b0;

        if (random_gap)
            gap = randomize_gap ();

        repeat (gap) @ (posedge clk);

    endtask

    //--------------------------------------------------------------------------

    task make_gap_between_tests ();

        repeat (max_latency + gap_between_tests)
            @ (posedge clk);

    endtask

    //--------------------------------------------------------------------------

    function [FLEN - 1:0] random_realbits ();

        logic [31:0] a, b;

        a = $urandom ();
        b = $urandom ();

        return FLEN' ({ a, b });

    endfunction

    //--------------------------------------------------------------------------
    // Driving stimulus

    localparam TIMEOUT = 10000;

    //--------------------------------------------------------------------------

    task run ();

        $display ("--------------------------------------------------");
        $display ("Running %m");

        // Init and reset

        arg_vld <= '0;
        reset ();

        $display ("********** Direct testing - a single test");

        a <= $realtobits ( 1 );
        b <= $realtobits ( 4 );
        c <= $realtobits ( 3 );

        drive_arg_vld ();
        make_gap_between_tests ();

        $display ("********** nan and inf - a single test");

        a <= $realtobits ( 1 );
        b <= nan;
        c <= $realtobits ( 4 );

        drive_arg_vld ();
        make_gap_between_tests ();

        a <= $realtobits ( 1 );
        b <= inf;
        c <= $realtobits ( 4 );

        drive_arg_vld ();
        make_gap_between_tests ();

        $display ("********** Direct testing - a group of tests");

        for (int i = 0; i < 100; i = i * 3 + 1)
        begin
            a <= $realtobits ( i       );
            b <= $realtobits ( i + 10  );
            c <= $realtobits ( i + 100 );

            drive_arg_vld
            (
                0,      // random_gap
                i / 10  // gap
            );
        end

        make_gap_between_tests ();

        $display ("********** Constraint random values back-to-back");

        repeat (100)
        begin
            a <= $realtobits ( $urandom () / 100000.0 ) ;
            b <= $realtobits ( $urandom () / 100000.0 ) ;
            c <= $realtobits ( $urandom () / 100000.0 ) ;

            drive_arg_vld ();
        end

        $display ("********** Random values and random gaps");

        repeat (100)
        begin
            a <= random_realbits ();
            b <= random_realbits ();
            c <= random_realbits ();

            drive_arg_vld (1); // random_gap
        end

        make_gap_between_tests ();

    endtask

    //--------------------------------------------------------------------------
    // Running testbench

    initial
    begin
        `ifdef __ICARUS__
            // Uncomment the following line
            // to generate a VCD file and analyze it using GTKwave

            $dumpvars;
        `endif

        run ();

        $finish;
    end

    //--------------------------------------------------------------------------
    // Utility tasks and functions

    function bit is_err (logic [FLEN - 1:0] a_bits);
        return a_bits [FLEN - 2 -: NE] === '1;
    endfunction

    //--------------------------------------------------------------------------

    function bit loose_comparison (logic [FLEN - 1:0] a, b);

        real ar, br, abs_a, abs_b, delta, max, k;
        bit close;

        if (a === b)
            return 1;

        ar = $bitstoreal (a); abs_a = ar >= 0 ? ar : - ar;
        br = $bitstoreal (b); abs_b = br >= 0 ? br : - br;

        delta = ar - br; if (delta < 0) delta = - delta;

        max = abs_a > abs_b ? abs_a : abs_b;

        k = 1000;
        close = delta * k < max;

        if (close)
        begin
            $write ("Loose comparison: %s %h versus %s %h:",
               `PG_BITS (a), a, `PG_BITS (b), b);

            $display (" delta %f * %f == %f < max %f",
                delta, k, delta * k, max);
        end

        return close;

    endfunction

    //--------------------------------------------------------------------------
    // Logging

    int unsigned cycle = 0;

    always @ (posedge clk)
    begin
        $write ("%s time %7d cycle %5d", test_id, $time, cycle);
        cycle <= cycle + 1'b1;

        if (rst)
            $write (" rst");
        else
            $write ("    ");

        if (arg_vld)
            // Optionaly change to `PF_BITS
            $write (" arg %s %s %s", `PG_BITS (a), `PG_BITS (b), `PG_BITS (c) );
        else
            $write ("                                     ");

        if (res_vld)
            $write (" res %s", `PG_BITS(res) );

        $display;
    end

    //--------------------------------------------------------------------------
    // Modeling and checking

    logic [FLEN - 1:0] queue [$];
    logic [FLEN - 1:0] res_expected;

    logic was_reset                = 0;
    bit   fail_is_already_reported = 0;

    // Blocking assignments are okay in this synchronous always block, because
    // data is passed using queue and all the checks are inside that always
    // block, so no race condition is possible

    // verilator lint_off BLKSEQ

    always @ (posedge clk)
    begin
        if (rst)
        begin
            queue = {};
            was_reset = 1;
        end
        else if (was_reset)
        begin
            if (arg_vld)
            begin
                res_expected = $realtobits
                (
                            $bitstoreal (a) ** 5
                    + 0.3 * $bitstoreal (b)
                    +       $bitstoreal (c)
                );

                queue.push_back (res_expected);
            end

            if (res_vld)
            begin
                if (queue.size () == 0)
                begin
                    $display ("FAIL %s: unexpected result %s",
                        test_id, `PG_BITS (res) );

                    $finish;
                end
                else
                begin
                    `ifdef __ICARUS__
                        // Some version of Icarus has a bug, and this is a workaround
                        res_expected = queue [0];
                        queue.delete (0);
                    `else
                        res_expected = queue.pop_front ();
                    `endif

                    if (! (   is_err (res_expected)
                           || res === res_expected
                           || $bitstoreal (res) == $bitstoreal (res_expected)
                           || loose_comparison (res, res_expected)))
                    begin
                        $display ("FAIL %s: res mismatch. Expected %s %h, actual %s %h",
                            test_id,
                            `PG_BITS (res_expected), res_expected,
                            `PG_BITS (res), res);

                        fail_is_already_reported = 1;
                        $finish;
                    end
                end
            end
        end
    end

    // verilator lint_on BLKSEQ

    //----------------------------------------------------------------------

    final
    begin
        if (fail_is_already_reported)
        begin
            // Do nothing
        end
        else if (queue.size () == 0)
        begin
            $display ("PASS %s", test_id);
        end
        else
        begin
            $write ("FAIL %s: data is left sitting in the model queue:",
                test_id);

            for (int i = 0; i < queue.size (); i ++)
                $write (" %h", queue [queue.size () - i - 1]);

            $display;
        end
    end

    //----------------------------------------------------------------------
    // Performance counters

    logic [32:0] n_cycles, arg_cnt, res_cnt;

    always @ (posedge clk)
        if (rst)
        begin
            n_cycles <= '0;
            arg_cnt  <= '0;
            res_cnt  <= '0;
        end
        else
        begin
            n_cycles <= n_cycles + 1'd1;

            if (arg_vld)
                arg_cnt <= arg_cnt + 1'd1;

            if (res_vld)
                res_cnt <= res_cnt + 1'd1;
        end

    //----------------------------------------------------------------------

    final
        $display ("\n\nnumber of transfers : arg %0d res %0d per %0d cycles",
            arg_cnt, res_cnt, n_cycles);

    //----------------------------------------------------------------------
    // Setting timeout against hangs

    initial
    begin
        repeat (TIMEOUT) @ (posedge clk);
        $display ("FAIL %s: timeout!", test_id);
        $finish;
    end

endmodule
