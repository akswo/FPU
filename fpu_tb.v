// File: FPU/8bit/fpu_tb.v
// Description: Testbench for the fpu_8bit_top module.

`timescale 1ns / 1ps

module fpu_tb;

    // Testbench signals to drive the DUT
    reg clk;
    reg rst_n;
    reg start;
    reg wr_en;
    reg [1:0] addr;
    reg [2:0] op_sel;
    reg [1:0] rnd_mode;
    reg [7:0] data_in;

    // DUT outputs to monitor
    wire busy;
    wire out_valid;
    wire [4:0] status;

    // Bidirectional data bus handling
    wire [7:0] data_from_dut;
    // The 'data' port connects to both the input driver and output monitor
    wire [7:0] data; 

    assign data_from_dut = data; // A wire to clearly read data from the DUT
    assign data = (wr_en) ? data_in : 8'bz; // Drive data_in when writing, otherwise high-Z

    // Instantiate the DUT (Device Under Test)
    fpu_8bit_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .wr_en(wr_en),
        .addr(addr),
        .op_sel(op_sel),
        .rnd_mode(rnd_mode),
        .data(data),
        .busy(busy),
        .out_valid(out_valid),
        .status(status)
    );

    // 1. Clock Generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period -> 100MHz clock
    end

    // 3. Verification Task (Automated Test)
    task verify_op;
        input [8*32:1] test_name; // Test Name String (Increased size)
        input [2:0] opcode;       // Operation Select
        input [7:0] val_a;        // Operand A
        input [7:0] val_b;        // Operand B
        input [7:0] exp_res;      // Expected Result
        reg [7:0] read_result;
        begin
            $display("\n--- Starting test: %s ---", test_name);
            
            // 0. Ensure we're in IDLE state
            start = 1'b0;
            wr_en = 1'b0;
            @(posedge clk);
            @(posedge clk);
            
            // 1. Write Operand A - set signals before clock edge
            @(negedge clk);  // Wait for negative edge for stable setup
            wr_en = 1'b1; 
            addr = 2'b00; 
            data_in = val_a;
            @(posedge clk);  // Now sample on positive edge
            $display("  Wrote op_a: %h", val_a);
            
            // 2. Write Operand B
            @(negedge clk);
            addr = 2'b01; 
            data_in = val_b;
            @(posedge clk);
            $display("  Wrote op_b: %h", val_b);

            // 3. Start Calculation
            @(negedge clk);
            wr_en = 1'b0; 
            addr = 2'b00;
            op_sel = opcode;
            start = 1'b1;
            @(posedge clk);
            $display("  Started calculation, opcode=%b", opcode);
            #1; // Hold start high to satisfy hold time requirements
            start = 1'b0;

            // 4. Wait for Completion
            wait (out_valid == 1'b1);
            $display("  Calculation complete (out_valid=1, busy=%b)", busy);
            
            // 5. Read & Check Result (immediately, no clock wait)
            addr = 2'b10;
            #1; // Small delay for combinational logic to settle
            read_result = data_from_dut;
            $display("  Read result: %h (expected: %h)", read_result, exp_res);
            
            if (read_result === exp_res) 
                $display("[PASS] %s", test_name);
            else                           
                $display("[FAIL] %s: got %h, expected %h", test_name, read_result, exp_res);
            
            // 6. Return to IDLE - FSM auto-returns, just wait
            @(posedge clk);
            @(posedge clk);
        end
    endtask

    // 2. Test Sequence
    initial begin
        $dumpfile("fpu_wave.vcd");
        $dumpvars(0, fpu_tb);

        $display("========================================");
        $display(" FPU Testbench Simulation Start ");
        $display("========================================");

        // --- Reset Sequence ---
        rst_n = 1'b0;
        start = 1'b0;
        wr_en = 1'b0;
        addr = 2'b00;
        op_sel = 3'b000;
        rnd_mode = 2'b00;
        data_in = 8'b0;
        #20;
        rst_n = 1'b1;
        #10;

        // --- Standard Tests ---
        // 1. Addition: 2.5 (0x42) + 1.25 (0x3A) = 3.75 (0x47)
        verify_op("ADD_Normal", 3'b000, 8'h42, 8'h3A, 8'h47);

        // 2. Multiplication: 3.0 (0x44) * 1.5 (0x3C) = 4.5 (0x49)
        verify_op("MUL_Normal", 3'b010, 8'h44, 8'h3C, 8'h49);

        // 3. Division: 6.0 (0x4C) / 2.0 (0x40) = 3.0 (0x44)
        verify_op("DIV_Normal", 3'b011, 8'h4C, 8'h40, 8'h44);

        // 4. Subtraction: 4.5 (0x49) - 1.5 (0x3C) = 3.0 (0x44)
        verify_op("SUB_Normal", 3'b001, 8'h49, 8'h3C, 8'h44);

        // --- Corner Case Tests (Real FPU Scenarios) ---
        // 5. Division by Zero: 1.0 (0x38) / 0.0 (0x00) = Inf (0x78)
        verify_op("DIV_By_Zero", 3'b011, 8'h38, 8'h00, 8'h78);

        // 6. Multiplication Overflow: 240.0 (0x7E) * 2.0 (0x40) = Inf (0x78)
        // Max Normal E4M3 = 1.111 * 2^7 = 240. 240*2 = 480 -> Overflow
        verify_op("MUL_Overflow", 3'b010, 8'h7E, 8'h40, 8'h78);
        
        $display("\n========================================");
        $display(" FPU Testbench Simulation End ");
        $display("========================================");
        $finish;
    end

endmodule