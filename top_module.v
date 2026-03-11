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
    localparam sub = 2'b01;
    localparam mul = 2'b10;
    localparam div = 2'b11;

    //addr -> decide whether data is input or output
    localparam in_A = 2'b00;
    localparam in_B = 2'b01;
    localparam out = 2'b10;

    //rnd_mode
    localparam to_zero = 2'b00;
    localparam to_neg_inf = 2'b01;
    localparam to_pos_inf = 2'b10;
    localparam to_even = 2'b11;
        
                    /* declare register */
    //data
    reg [7:0] input_A;
    reg [7:0] input_B;
    reg [7:0] output_data;
    //state
    reg [1:0] state, next_state;
    reg calc_done;
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            state <= IDLE;
            input_A <= 8'b0;
            input_B <= 8'b0;
            output_data <= 8'b0;
            calc_done <= 1'b0;
        end
        else begin
            state<=next_state;     

            if(wr_en && addr == in_A)
                input_A <= data;
            if(wr_en && addr == in_B)
                input_B <= data;
            
            if(state == DONE)
                calc_done <= 1'b0;
        end
    end
    always@(*) begin
        case (state)
            IDLE : begin
                if (start) next_state = CALC;
                else next_state = IDLE; 
            end
            CALC : begin
                if(calc_done) next_state = DONE;
                else next_state = CALC;                
            end
            DONE : begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end


endmodule