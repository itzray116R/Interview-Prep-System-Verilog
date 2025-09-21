module mux(
	input logic [3:0] data_in,
	input logic [1:0] sel,
	output logic dout
);

	always @* begin
		case(sel)
			2'b00: dout = data_in[0];
			2'b01: dout = data_in[1];
			2'b10: dout = data_in[2];
			2'b11: dout = data_in[3];
			default: dout = 1'b0;
		endcase
	end
endmodule

// Testbench for the multiplexer with verification
module mux_tb;
    logic [3:0] data_in;
    logic [1:0] sel;
    logic data_out;
    logic expected;
    integer error_count = 0;
    integer test_count = 0;
    
    // Instantiate the mux
    mux dut (
        .data_in(data_in),
        .sel(sel),
        .dout(data_out)
    );
    
    task test_input(input [3:0] data, input [1:0] select, input exp);
        data_in = data;
        sel = select;
        #1; // Wait for propagation
        test_count++;
        if (data_out !== exp) begin
            $display("ERROR: sel=%b, data_in=%b, expected=%b, got=%b", sel, data_in, exp, data_out);
            error_count++;
        end else begin
            $display("PASS:  sel=%b, data_in=%b, output=%b", sel, data_in, data_out);
        end
    endtask
    
    initial begin
        $display("Testing 4:1 Multiplexer");
        $display("=========================");
        
        // Test various patterns
        test_input(4'b1010, 2'b00, 1'b0);
        test_input(4'b1010, 2'b01, 1'b1);
        test_input(4'b1010, 2'b10, 1'b0);
        test_input(4'b1010, 2'b11, 1'b1);
        
        test_input(4'b1100, 2'b00, 1'b0);
        test_input(4'b1100, 2'b01, 1'b0);
        test_input(4'b1100, 2'b10, 1'b1);
        test_input(4'b1100, 2'b11, 1'b1);
        
        // Edge cases
        test_input(4'b1111, 2'b00, 1'b1);
        test_input(4'b1111, 2'b11, 1'b1);
        test_input(4'b0000, 2'b01, 1'b0);
        test_input(4'b0001, 2'b00, 1'b1);
        
        // Summary
        $display("=========================");
        $display("Tests run: %0d", test_count);
        $display("Errors: %0d", error_count);
        
        if (error_count == 0) begin
            $display("ALL TESTS PASSED! ✅");
        end else begin
            $display("TESTS FAILED! ❌");
        end
        
        #10 $finish;
    end
    
endmodule