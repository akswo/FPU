module top_module (
    input        VDD, VSS,
    input        clk, rst_n,
    input        start, wr_en,
    input  [1:0] addr,
    input  [1:0] op_sel,
    input  [1:0] rnd_mode,
    inout  [7:0] data,
    output reg   busy,
    output reg   out_valid,
    output reg [3:0] status
);
                    /*declare localparam*/
    //state
    localparam IDLE = 2'b00;
    localparam CALC = 2'b01;
    localparam DONE = 2'b10;

    //STATUS
    localparam STATUS_IDLE = 4'b0000;
    localparam STATUS_BUSY = 4'b0001;
    localparam STATUS_DONE = 4'b0010;
    localparam STATUS_DIVZERO = 4'b0100;
    localparam STATUS_INV_OP = 4'b1000;
    
    //op_sel
    localparam add = 2'b00;
    localparam mul = 2'b01;
    localparam div = 2'b10;

    //addr -> decide whether data is input or output
    localparam in_A = 2'b00;
    localparam in_B = 2'b01;
    localparam out = 2'b10;


                    /* declare register */
    //data
    reg [7:0] input_A;
    reg [7:0] input_B;
    reg [7:0] output_data;
endmodule