`timescale 1ps/1ps

//`define JITTER_ENABLE
//`define JITTER 0.2     // 20% Jitter means period +/- 20%
//`define PLL_DEBUG

module amos_c14pl550m_flf ( clkfbo, clkout, clkrefo, fr, lock, mack, nack, out0,
       out1, pack, so, gnd, gnda, vcon, vdd, vdda, async_test, bandsel, bypass, 
       clk_test, clken, clkin, directi, directo, frm, inseli, inselp, inselr,
       limup_off, logic_scantest, mdec, mreq, ndec, nreq, pd, pdec, preq, se,
       seli, selp, selr, si, skew_en, skewin);

    output clkout;
    output fr;
    output lock;
    output mack;               // tied in RTL so I have not modeled this behaviour
    output nack;
    output pack;
    output so;
    inout vdda;
    inout gnda;
    input bypass;              // bypass pll
    input clken;
    input clkin;
    input directi;             // bypass input divider
    input directo;             // bypass post divider
    input frm;                 // free running mode
    input mreq;                // request to change feedback divider value
    input [16:0] mdec;         // feedback divider  [1..2^15]
    input nreq;                // request to change pre-divider value
    input [9:0] ndec;          // Pre-divider  [1..2^8]
    input pd;                  // Power down PLL
    input preq;                // Request to change Post divider
    input [6:0] pdec;          // post divider [1..2^5]
    input logic_scantest;
    input skew_en;
    input bandsel;             // select between filter parameters sel-0 or insel-1
    input [3:0] inselr;        // filter parameters r,i,p
    input [3:0] inseli;
    input [4:0] inselp;
    input [3:0] selr;          // filter parameters r,i,p
    input [3:0] seli;
    input [4:0] selp;
    input skewin;
    input clk_test;
    input si;
    input se;
    output clkrefo;
    output clkfbo;
    output out0;
    output out1;
    input async_test;
    input limup_off;
    inout vcon;   
    inout gnd;
    inout vdd;

    time    last_tick;
    time    clkin_period_inst;
    time    clkin_period_avg;
    time    clkin_period_avg_str;
    real    clkout_period_fix;        // Real to increase clkout f precision
    integer clkout_period_jit;        // period with jitter

    reg        clkout_int;
    reg        lock_int = 0;
    reg [16:0] mdec_reg = 10;
    reg [6:0]  pdec_reg = 10;
    reg [9:0]  ndec_reg = 10;
    integer    i = 0;
    integer    err_cnt = 0;
    integer    jitter;

    initial
    begin
        last_tick = 0;
        clkin_period_inst = 100;
        clkin_period_avg = 100;
        clkin_period_avg_str = 100;
        clkout_period_fix = 100;
        clkout_period_jit = 100;
    end

    always @(pd)
    begin
        if (pd == 0) // negedge
        begin
            mdec_reg = mdec + 1;  // Add one to signal value
            pdec_reg = pdec + 1;
            ndec_reg = ndec + 1;
        end
        else         // posedge
        begin
            lock_int   = 0;
            clkout_int = 0;
        end
    end

    // Measure average input clock frequency
    // When it changes the pll loses lock
    always @(posedge clkin)
    begin
        clkin_period_inst = $time - last_tick;
        // cumulative average reset every 20 clock cycles
        clkin_period_avg = (clkin_period_inst + (i*clkin_period_avg))/(i+1); 
        i = i + 1;
        if (i == 20) 
        begin
            i = 0;
            if (clkin_period_avg_str > clkin_period_avg * 0.98 &&
                clkin_period_avg_str < clkin_period_avg * 1.02)
                lock_int = 1;
            else
                lock_int = 0;
            clkin_period_avg_str = clkin_period_avg;
        end
        last_tick = $time;
    end

    // Calculate output clock frequency on changed of parameters
    always @(mdec_reg, pdec_reg, ndec_reg, clkin_period_inst, directi, directo)
    begin
        case ({directi, directo})
            2'b11 : clkout_period_fix =            ( $itor(clkin_period_inst) / (2 * mdec_reg) );
            2'b10 : clkout_period_fix =            ( $itor(clkin_period_inst) / (2 * mdec_reg) ) * (2 * pdec_reg);
            2'b01 : clkout_period_fix = ndec_reg * ( $itor(clkin_period_inst) / (2 * mdec_reg) );
            2'b00 : clkout_period_fix = ndec_reg * ( $itor(clkin_period_inst) / (2 * mdec_reg) ) * (2 * pdec_reg);
        endcase
        lock_int = 0;
        $display("PLL clkout frequency changing to %f Hz",(1.0/clkout_period_fix)*1e12); // Assume timescale picoseconds
    end

    // Create the output clock
    always begin
        // Add jitter to clkout
        `ifdef JITTER_ENABLE
            // Uniform distribution. Gaussian would probably be better...
            jitter = $random % ($rtoi((clkout_period_fix * (`JITTER)))); // change to (`JITTER >> 1), if you want 0.1 to mean +/- 5%
        `else
            jitter = 0;
        `endif
        clkout_period_jit = clkout_period_fix + jitter;
        `ifdef PLL_DEBUG
            $display("-*-*-*-");
            $display("mdec=%10d",mdec_reg,"\npdec=%10d",pdec_reg,"\nndec=%10d",ndec_reg);
            $display("clkin_period_avg_str=%15d",clkin_period_avg_str,"ps\nclkout period       =%15f",clkout_period_fix,"ps");
            `ifdef JITTER_ENABLE
                $display("Jitter ",`JITTER*100,"%%, jitter ",jitter,"ps");
            `endif
        `endif
        clkout_int = 0;
        if (clkout_period_jit >= 2)
            #(clkout_period_jit/2);
        else begin
            err_cnt = err_cnt + 1;
            if (err_cnt < 50)
                $display("ERROR - PLL_MODEL: Invalid zero clkout period @",$time);
            #(1000);
        end
        clkout_int = 1;
        #(clkout_period_jit/2);
    end

    // Drive outputs
    assign clkout = (vdd !== 1 || vdda !== 1 || gnd !== 0 || gnda !== 0 || pd !== 0) ? 1'bx :
                    (clken === 0) ? 0 :
                    (bypass == 0) ? clkout_int : clkin;

    assign lock = (vdd !== 1 || vdda !== 1 || gnd !== 0 || gnda !== 0 || pd !== 0) ? 1'bx :
                  lock_int;


    // don't drive INOUT ports
    assign  vdda = 1'bz;
    assign  gnda = 1'bz;
    assign  vdd = 1'bz;
    assign  gnd = 1'bz;

    // Assign unused outputs to zero, otherwards they will be z
    assign fr      = 0;
    assign mack    = 0;
    assign nack    = 0;
    assign pack    = 0;
    assign so      = 0;
    assign clkrefo = 0;
    assign clkfbo  = 0;
    assign out0    = 0;  // must be tied off to 0
    assign out1    = 1;  // must be tied off to 1

    // Assertions: *** Below is the only SystemVerilog code ***
    // 1. Check that the mdec,ndec, pdec signals are stable at pd falling edge

endmodule
