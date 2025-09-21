module ff_async_rst(
    input logic clk,
    input logic async_rst,
    input logic d,
    output logic q 
);

    always_ff @(posedge clk or posedge async_rst) begin
        if (async_rst) begin
            q <= 1'b0; // reset when reset is high (asynchronous)
        end else begin
            q <= d; // normal operation
        end
    end
endmodule

module ff_sync_rst(
    input logic clk,
    input logic sync_rst,
    input logic d,
    output logic q 
);
    // only sensitive to clock edge (synchronous)
    always_ff @(posedge clk) begin 
        if (sync_rst) begin
            q <= 1'b0; // reset only on clock edge
        end else begin
            q <= d; // normal operation
        end
    end
endmodule

module ff_testbench;
    logic clk;
    logic async_rst, sync_rst;
    logic d;
    logic q_async, q_sync;
    
    integer test_count = 0;
    integer async_errors = 0;
    integer sync_errors = 0;
    
    // Instantiate the flip flops
    ff_async_rst async_ff (
        .clk(clk),
        .async_rst(async_rst),
        .d(d),
        .q(q_async)
    );
    
    ff_sync_rst sync_ff (
        .clk(clk),
        .sync_rst(sync_rst),
        .d(d),
        .q(q_sync)
    );
    
    // Clock generation (100MHz)
    always #5 clk = ~clk;
    
    initial begin
        // Initialize signals
        clk = 0;
        async_rst = 0;
        sync_rst = 0;
        d = 0;
        
        $display("Testing Asynchronous vs Synchronous Reset Flip Flops");
        $display("==================================================================================");
        $display("Time\tclk\tasync_rst\tsync_rst\td\tq_async\tq_sync\tTest");
        $display("==================================================================================");
        
        // Test 1: Initial state
        #10;
        display_status("Initial state");
        
        // Test 2: Normal operation - set both to 1
        d = 1;
        #10;
        display_status("Set d=1");
        verify_async(1, "Async: should follow d");
        verify_sync(1, "Sync: should follow d");
        
        // Test 3: Synchronous reset (should reset on next clock edge)
        sync_rst = 1;
        #5; // Before clock edge
        display_status("Sync reset asserted (before clock edge)");
        verify_sync(1, "Sync: should not reset yet");
        
        #5; // Clock edge
        display_status("After clock edge - sync should reset");
        verify_sync(0, "Sync: should reset now");
        
        sync_rst = 0;
        #10;
        display_status("Sync reset released");
        
        // Test 4: Asynchronous reset (should reset immediately)
        async_rst = 1;
        #1; // Small delay to see immediate effect
        display_status("Async reset asserted (immediate effect)");
        verify_async(0, "Async: should reset immediately");
        
        #9 async_rst = 0;
        display_status("Async reset released");
        verify_async(0, "Async: should stay reset until next clock");
        
        // Test 5: Set both to 1 again
        d = 1;
        #10;
        display_status("Set d=1 again");
        verify_async(1, "Async: should follow d");
        verify_sync(1, "Sync: should follow d");
        
        // Test 6: Test both resets simultaneously
        async_rst = 1;
        sync_rst = 1;
        #1;
        display_status("Both resets asserted");
        verify_async(0, "Async: should reset immediately");
        verify_sync(1, "Sync: should not reset yet");
        
        #9; // Wait for clock edge
        display_status("After clock edge - both should be reset");
        verify_async(0, "Async: should stay reset");
        verify_sync(0, "Sync: should reset now");
        
        async_rst = 0;
        sync_rst = 0;
        #10;
        display_status("Both resets released");
        
        // Test 7: Test reset between clock edges - FIXED TIMING
        d = 1;
        #10;
        display_status("Set d=1");
        
        #2; // Between clock edges (2ns after posedge)
        async_rst = 1;
        sync_rst = 1;
        #1;
        display_status("Resets asserted between clock edges");
        verify_async(0, "Async: should reset immediately");
        verify_sync(1, "Sync: should not reset yet");
        
        #7; // Wait for next clock edge (total 10ns from last edge)
        display_status("After clock edge");
        verify_async(0, "Async: should stay reset");
        verify_sync(0, "Sync: should reset now");
        
        async_rst = 0;
        sync_rst = 0;
        #10;
        display_status("Resets released");
        
        // Summary
        $display("==================================================================================");
        $display("TEST SUMMARY:");
        $display("Total tests: %0d", test_count);
        $display("Async FF errors: %0d", async_errors);
        $display("Sync FF errors: %0d", sync_errors);
        
        if (async_errors == 0 && sync_errors == 0) begin
            $display("ALL TESTS PASSED! ✅");
        end else begin
            $display("SOME TESTS FAILED! ❌");
        end
        
        #10 $finish;
    end
    
    task display_status(string comment);
        $display("%0t\t%b\t%b\t\t%b\t\t%b\t%b\t%b\t%s", 
                $time, clk, async_rst, sync_rst, d, q_async, q_sync, comment);
    endtask
    
    task verify_async(input logic expected, string message);
        test_count++;
        if (q_async !== expected) begin
            $display("ERROR: %s (got %b, expected %b)", message, q_async, expected);
            async_errors++;
        end
    endtask
    
    task verify_sync(input logic expected, string message);
        test_count++;
        if (q_sync !== expected) begin
            $display("ERROR: %s (got %b, expected %b)", message, q_sync, expected);
            sync_errors++;
        end
    endtask
    
endmodule