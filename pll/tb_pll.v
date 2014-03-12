`timescale 1ns/1ns

module tb;
    reg clkin, bypass;
    reg [16:0] mdec;
    reg [9:0]  ndec;
    reg [6:0]  pdec;
    reg        pd;
    wire vdda, gnda, gnd, vcon, vdd;

    amos_c14pl550m_flf pll (
        .clkout            (),
        .fr                (),
        .lock              (),
        .mack              (),
        .nack              (),
        .pack              (),
        .so                (),
        .vdda              (vdda),
        .gnda              (gnda), 
        .bypass            (bypass),
        .clken             (1'b1),
        .clkin             (clkin),
        .directi           (1'b1),
        .directo           (1'b1),
        .frm               (1'b0),
        .mreq              (1'b0),
        .mdec              (mdec),  // feedback divider  [1..2^15]
        .nreq              (1'b0),
        .ndec              (ndec),  // Pre-divider  [1..2^8]
        .pd                (pd),    // Power down
        .preq              (1'b0),
        .pdec              (pdec),  // post divider [1..2^5]
        .logic_scantest    (1'b0),
        .skew_en           (1'b0),
        .bandsel           (1'b0),
        .inselr            (4'b0),
        .inseli            (4'b0),
        .inselp            (5'b0),
        .selr              (4'b0),
        .seli              (4'b0),
        .selp              (5'b0), 
        .skewin            (1'b0),
        .clk_test          (1'b0),
        .si                (1'b0),
        .se                (1'b0),
        .clkrefo           (),
        .clkfbo            (),
        .out0              (),
        .out1              (),
        .async_test        (1'b0),
        .limup_off         (1'b0),
        .vcon              (vcon),   
        .gnd               (gnd),
        .vdd               (vdd)
    );

    initial begin
        clkin = 0;
        mdec  = 40;
        ndec  = 2;
        pdec  = 4;
        pd    = 1;
        #1000;
        pd    = 0;
        #1000;
        forever begin
            clkin = 1;
            #1500;
            clkin = 0;
            #1500;
        end
    end    
    
    initial begin
        bypass = 0;
        #190000
        bypass = 1;
        #80000
        bypass = 0;
    end    
    
    assign vdd   = 1;
    assign vcon  = 1;
    assign vdda  = 1;
    assign gnd   = 0;
    assign gnda  = 0;


endmodule
