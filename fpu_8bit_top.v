// File: FPU/8bit/fpu_8bit_top.v
// Description: Top-level module for the 8-bit FPU.
//              Manages I/O, FSM, and instantiates arithmetic units.

module fpu_8bit_top (
    // Clock / Reset
    input wire clk,
    input wire rst_n,

    // Control Signals
    input wire start,
    input wire wr_en,
    input wire [1:0] addr,
    input wire [2:0] op_sel,
    input wire [1:0] rnd_mode,

    // Data Bus (Bidirectional)
    inout wire [7:0] data,

    // Status Signals
    output reg busy,
    output reg out_valid,
    output reg [4:0] status
);

    // FSM States
    localparam S_IDLE = 2'b00;
    localparam S_CALC = 2'b01;
    localparam S_DONE = 2'b10;

    // Latency for multi-cycle operations - Apply actual hardware delay time
    localparam CALC_LATENCY = 3'd4; 

    // State Registers
    reg [1:0] current_state, next_state;

    // Data & Control Registers
    reg [7:0] reg_op_a;
    reg [7:0] reg_op_b;
    reg [7:0] reg_result;
    reg [2:0] latched_op_sel;
    reg [1:0] latched_rnd_mode;

    // Internal Counters & Flags
    reg [2:0] calc_cnt;
    reg calc_done;

    // Wires for ALU results
    wire [7:0] res_add;
    wire [7:0] res_sub;
    wire [7:0] res_mul;
    wire [7:0] res_div;

    // Divider Control Signals
    reg div_start;
    wire div_done;

    //-------------------------------------------------
    // Instantiate Arithmetic Units
    //-------------------------------------------------
    
    // Adder
    fp_adder u_adder (
        .a(reg_op_a), .b(reg_op_b), .res(res_add)
    );
    
    // Subtractor (reuses adder by negating operand B)
    wire [7:0] op_b_neg = {~reg_op_b[7], reg_op_b[6:0]};
    fp_adder u_subtractor (
        .a(reg_op_a), .b(op_b_neg), .res(res_sub)
    );

    // Multiplier
    fp_multiplier u_multiplier (
        .a(reg_op_a), .b(reg_op_b), .res(res_mul)
    );

    // Divider
    fp_divider u_divider (
        .clk(clk), .rst_n(rst_n), .start(div_start),
        .a(reg_op_a), .b(reg_op_b), .res(res_div),
        .done(div_done)
    );

    //-------------------------------------------------
    // Bidirectional Data Bus Control
    //-------------------------------------------------
    reg [7:0] internal_data_out;

    always @(*) begin
        case (addr)
            2'b00: internal_data_out = reg_op_a;
            2'b01: internal_data_out = reg_op_b;
            2'b10: internal_data_out = reg_result;
            2'b11: internal_data_out = {3'b000, status};
            default: internal_data_out = 8'h00;
        endcase
    end

    assign data = (wr_en == 1'b0) ? internal_data_out : 8'bz;

    //-------------------------------------------------
    // FSM Logic
    //-------------------------------------------------
    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
        end else begin
            if (current_state != next_state) begin
                // debug print
                // $display("DEBUG: FSM %d -> %d at time %t (start=%b, calc_done=%b)", 
                //          current_state, next_state, $time, start, calc_done);
            end
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            S_IDLE: if (start) next_state = S_CALC;
            S_CALC: if (calc_done) next_state = S_DONE;
            S_DONE: next_state = S_IDLE;  // Always return to IDLE after DONE
        endcase
    end

    // Output and Register Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            reg_op_a <= 0; reg_op_b <= 0; reg_result <= 0;
            status <= 0; busy <= 0; out_valid <= 0;
            calc_cnt <= 0; calc_done <= 0;
            latched_op_sel <= 0; latched_rnd_mode <= 0;
            div_start <= 0;
        end else begin
            case (current_state)
                S_IDLE: begin
                    busy <= 1'b0;
                    out_valid <= 1'b0;
                    calc_done <= 1'b0;
                    calc_cnt <= 3'b0;
                    div_start <= 1'b0;

                    if (wr_en) begin
                        if (addr == 2'b00) begin
                            reg_op_a <= data;
                            // debug print
                            // $display("DEBUG: FPU loaded op_a = %h at time %t", data, $time);
                        end
                        if (addr == 2'b01) begin
                            reg_op_b <= data;
                            // debug print
                            // $display("DEBUG: FPU loaded op_b = %h at time %t", data, $time);
                        end
                    end
                    
                    if (start) begin
                        latched_op_sel <= op_sel;
                        latched_rnd_mode <= rnd_mode;
                        // debug print
                        // $display("DEBUG: FPU starting calc, opsel=%b, op_a=%h, op_b=%h at time %t", 
                        //          op_sel, reg_op_a, reg_op_b, $time);
                    end
                end

                S_CALC: begin
                    busy <= 1'b1;
                    out_valid <= 1'b0;
                    
                    // Handle Division separately (Sequential)
                    if (latched_op_sel == 3'b011) begin
                        if (calc_cnt == 0) begin
                            div_start <= 1'b1; // Pulse start
                            calc_cnt <= 1;     // Mark as started to prevent re-triggering
                        end else begin
                            div_start <= 1'b0;
                        end

                        if (div_done) begin
                            calc_done <= 1'b1;
                        end
                    end else begin
                        // Handle Combinational Units (Add/Sub/Mul) with fixed latency
                        if (calc_cnt < CALC_LATENCY) begin
                            calc_cnt <= calc_cnt + 1;
                        end
                        if (calc_cnt == CALC_LATENCY - 1) begin
                            calc_done <= 1'b1;
                        end
                    end

                    if (calc_done) begin
                        // Select result from the correct ALU
                        case (latched_op_sel)
                            3'b000: begin
                                reg_result <= res_add;
                                // debug print
                                // $display("DEBUG: Storing ADD result = %h (op_a=%h, op_b=%h) at time %t", 
                                //          res_add, reg_op_a, reg_op_b, $time);
                            end
                            3'b001: begin
                                reg_result <= res_sub;
                                // debug print
                                // $display("DEBUG: Storing SUB result = %h at time %t", res_sub, $time);
                            end
                            3'b010: begin
                                reg_result <= res_mul;

                                // $display("DEBUG: Storing MUL result = %h at time %t", res_mul, $time);
                            end
                            3'b011: begin
                                reg_result <= res_div;
                                // debug print
                                // $display("DEBUG: Storing DIV result = %h at time %t", res_div, $time);
                            end
                            default: begin
                                reg_result <= 8'h00;
                                // debug print
                                // $display("DEBUG: Storing DEFAULT result = 00 at time %t", $time);
                            end
                        endcase
                        
                        // Status flags should be updated by ALUs
                        status <= 5'b00000; // Placeholder
                    end
                end

                S_DONE: begin
                    busy <= 1'b0;
                    out_valid <= 1'b1;
                    // Keep calc_done high until returning to IDLE
                end
            endcase
        end
    end

endmodule
