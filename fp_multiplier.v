// File: FPU/8bit/fp_multiplier.v
// Description: 8-bit Floating Point (E4M3) Multiplier.
//              This is a combinational logic block.

module fp_multiplier (
    input wire [7:0] a,
    input wire [7:0] b,
    output reg [7:0] res
);

    wire sign_a = a[7];
    wire [3:0] exp_a = a[6:3];
    wire [3:0] mant_a = {1'b1, a[2:0]};

    wire sign_b = b[7];
    wire [3:0] exp_b = b[6:3];
    wire [3:0] mant_b = {1'b1, b[2:0]};

    localparam BIAS = 7;

    reg final_sign;
    reg [4:0] temp_exp;
    reg [7:0] mant_mult;
    reg [4:0] final_exp;
    reg [2:0] final_mant;

    always @(*) begin
        // Initialize to avoid latches
        final_sign = 0;
        temp_exp = 0;
        mant_mult = 0;
        final_exp = 0;
        final_mant = 0;
        res = 0;

        if (a[6:0] == 0 || b[6:0] == 0) begin
            res = 8'b0;
        end else begin
            // 1. Sign is XOR of input signs
            final_sign = sign_a ^ sign_b;

            // 2. Add exponents and subtract bias
            temp_exp = exp_a + exp_b - BIAS;

            // 3. Multiply mantissas
            mant_mult = mant_a * mant_b;

            // 4. Normalize
            if (mant_mult[7]) begin // Result is 1x.xxxxxx, shift right
                final_exp = temp_exp + 1;
                final_mant = mant_mult[6:4];
            end else begin // Result is 01.xxxxxx, use as is
                final_exp = temp_exp;
                final_mant = mant_mult[5:3];
            end

            // 5. Pack and check for overflow/underflow
            if (final_exp >= 15) begin
                res = {final_sign, 4'b1111, 3'b000}; // Infinity
            end else if (final_exp[4] == 1) begin // Negative exponent -> underflow
                res = 8'b0; // Flush to zero
            end else begin
                res = {final_sign, final_exp[3:0], final_mant};
            end
        end
    end
endmodule
