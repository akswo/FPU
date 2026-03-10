// File: FPU/8bit/fp_adder.v
// Description: 8-bit Floating Point (E4M3) Adder.
//              This is a combinational logic block.

module fp_adder (
    input wire [7:0] a,
    input wire [7:0] b,
    output reg [7:0] res
);

    // E4M3 format: 1-bit sign, 4-bit exponent, 3-bit mantissa
    wire sign_a = a[7];
    wire [3:0] exp_a = a[6:3];
    wire [3:0] mant_a = {1'b1, a[2:0]}; // Add hidden bit

    wire sign_b = b[7];
    wire [3:0] exp_b = b[6:3];
    wire [3:0] mant_b = {1'b1, b[2:0]};

    reg [3:0] exp_diff;
    reg [3:0] larger_exp;
    reg [4:0] final_exp;
    reg [4:0] shifted_mant_a, shifted_mant_b;
    reg [5:0] mant_sum;
    reg final_sign;
    reg [2:0] final_mant;

    always @(*) begin
        // Initialize to avoid latches
        exp_diff = 0;
        larger_exp = 0;
        final_exp = 0;
        shifted_mant_a = 0;
        shifted_mant_b = 0;
        mant_sum = 0;
        final_sign = 0;
        final_mant = 0;
        res = 0;

        // Handle Zero Inputs
        if (a[6:0] == 0) begin
            res = b;
            // debug print
            // $display("DEBUG ADD: a=0, returning b=%h", b);
        end else if (b[6:0] == 0) begin
            res = a;
            // debug print
            // $display("DEBUG ADD: b=0, returning a=%h", a);
        end else begin
            // 1. Align Exponents
            if (exp_a >= exp_b) begin
                larger_exp = exp_a;
                exp_diff = exp_a - exp_b;
                shifted_mant_a = {mant_a, 1'b0};
                shifted_mant_b = {mant_b, 1'b0} >> exp_diff;
            end else begin
                larger_exp = exp_b;
                exp_diff = exp_b - exp_a;
                shifted_mant_a = {mant_a, 1'b0} >> exp_diff;
                shifted_mant_b = {mant_b, 1'b0};
            end

            // 2. Add/Subtract Mantissas
            if (sign_a == sign_b) begin // Addition
                mant_sum = shifted_mant_a + shifted_mant_b;
                final_sign = sign_a;
            end else begin // Subtraction
                if (shifted_mant_a >= shifted_mant_b) begin
                    mant_sum = shifted_mant_a - shifted_mant_b;
                    final_sign = sign_a;
                end else begin
                    mant_sum = shifted_mant_b - shifted_mant_a;
                    final_sign = sign_b;
                end
            end

            // 3. Normalize Result
            if (mant_sum[5]) begin // Carry-out from addition
                final_exp = larger_exp + 1;
                final_mant = mant_sum[4:2]; // Shift right
            end else if (mant_sum[4]) begin // Normal range
                final_exp = larger_exp;
                final_mant = mant_sum[3:1];
            end else if (mant_sum != 0) begin // Denormalized after subtraction, needs left shift
                // Simplified: This requires a loop or priority encoder for full correctness.
                // For this model, we assume at most one left shift is needed.
                if (mant_sum[3]) begin
                    final_exp = larger_exp - 1;
                    final_mant = mant_sum[2:0];
                end else begin // Further shifts needed
                    final_exp = 0; // Treat as zero for simplicity
                    final_mant = 0;
                end
            end else begin // Result is zero
                final_exp = 0;
                final_mant = 0;
            end

            // 4. Pack Result and check for overflow
            if (final_exp >= 15) begin
                res = {final_sign, 4'b1111, 3'b000}; // Infinity
            end else if (final_exp == 0 && final_mant == 0) begin
                res = 8'b0; // True zero
            end else begin
                res = {final_sign, final_exp[3:0], final_mant};
            end
        end
    end
endmodule
