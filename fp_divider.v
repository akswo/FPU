// File: FPU/8bit/fp_divider.v
// Description: Behavioral model for an 8-bit Floating Point (E4M3) Divider.
//              Updated: Uses Restoring Division (Sequential Logic) for synthesis.

module fp_divider (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a,
    input wire [7:0] b,
    output reg [7:0] res,
    output reg done
);

    // Unpack inputs
    wire sign_a = a[7];
    wire [3:0] exp_a = a[6:3];
    wire [3:0] mant_a = {1'b1, a[2:0]};

    wire sign_b = b[7];
    wire [3:0] exp_b = b[6:3];
    wire [3:0] mant_b = {1'b1, b[2:0]};

    localparam BIAS = 7;

    // FSM States
    localparam S_IDLE = 2'b00;
    localparam S_CALC = 2'b01;
    localparam S_NORM = 2'b10;

    reg [1:0] state;
    reg [3:0] count;
    
    // Internal registers for calculation
    reg calc_sign;
    reg [4:0] calc_exp;
    reg [7:0] quotient;
    reg [8:0] remainder; // 1 bit extra for shift
    reg [3:0] divisor;
    
    // Internal variables for normalization (moved from local block)
    reg [4:0] final_exp;
    reg [2:0] final_mant;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            res <= 0;
            done <= 0;
            quotient <= 0;
            remainder <= 0;
            divisor <= 0;
            calc_exp <= 0;
            calc_sign <= 0;
            count <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Handle Special Cases
                        if (b[6:0] == 0) begin // Div by Zero
                            res <= {a[7], 4'b1111, 3'b000}; // Infinity
                            done <= 1;
                        end else if (a[6:0] == 0) begin // 0 / x
                            res <= 0;
                            done <= 1;
                        end else begin
                            // Initialize for Division
                            calc_sign <= sign_a ^ sign_b;
                            calc_exp <= exp_a - exp_b + BIAS;
                            
                            // Setup for 1.xxx / 1.xxx
                            // We shift Dividend left by 4 to get precision
                            remainder <= {2'b00, mant_a, 3'b000}; 
                            divisor <= mant_b;
                            quotient <= 0;
                            count <= 0;
                            state <= S_CALC;
                        end
                    end
                end

                S_CALC: begin
                    // Simple Restoring Division (6 iterations for enough precision)
                    // We need 4 bits (1.xxx) + guard bits
                    if (count < 6) begin
                        remainder <= remainder << 1;
                        // Check if we can subtract (using non-blocking, check next value)
                        // Logic: (rem << 1) >= (div << 4)? 
                        // Simplified: We are generating quotient bits MSB first.
                        // Effective comparison happens in the next cycle logic usually, 
                        // but here we do it in one cycle using combinational check on current regs.
                        if ( (remainder << 1) >= {1'b0, divisor, 4'b0000} ) begin
                             remainder <= (remainder << 1) - {1'b0, divisor, 4'b0000};
                             quotient <= {quotient[6:0], 1'b1};
                        end else begin
                             quotient <= {quotient[6:0], 1'b0};
                        end
                        count <= count + 1;
                    end else begin
                        state <= S_NORM;
                    end
                end

                S_NORM: begin
                    // Normalize Quotient
                    // Quotient has 6 bits. E.g., 1.xxx... or 0.1xxx...
                    // Since 1 <= mant < 2, 0.5 < res < 2.
                    // If res >= 1 (bit 5 is 1), no shift needed.
                    // If res < 1 (bit 5 is 0), shift left, dec exp.
                    
                    final_exp = calc_exp;
                    
                    if (quotient[5]) begin // >= 1.0
                        final_mant = quotient[4:2];
                    end else begin // < 1.0 (0.1xxxx)
                        final_exp = calc_exp - 1;
                        final_mant = quotient[3:1];
                    end

                    // Overflow/Underflow Check
                    if (final_exp >= 15) begin
                        res <= {calc_sign, 4'b1111, 3'b000}; // Inf
                    end else if (final_exp[4] == 1) begin // Negative exp
                        res <= 0; // Underflow
                    end else begin
                        res <= {calc_sign, final_exp[3:0], final_mant};
                    end
                    
                    done <= 1;
                    state <= S_IDLE;
                end
            endcase
        end
    end
endmodule
