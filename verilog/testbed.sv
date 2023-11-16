module dds_tb();
    reg clk;

    reg sys_clk; 
    reg spi_clk;
    reg spi_data;
    reg freq_cs;
    reg phaseshift_cs;
    reg [1:0] mode_in;
    wire [7:0] waveform_out;

    dds #(
        .PHASE_LENGTH(8), 
        .ACC_LENGTH(16)
    ) dut (
        .sys_clk(clk), 
        .spi_clk(spi_clk), 
        .spi_data(spi_data), 
        .freq_cs(freq_cs), 
        .phaseshift_cs(phaseshift_cs), 
        .mode_in(mode_in), 
        .waveform_out(waveform_out)
    );

    initial begin
        clk = 1'b0;
        #10
        forever #1 clk = ~clk; 
    end

    initial begin 
        // Load a few bits into the freq register
        freq_cs = 1;
        spi_clk = 0;
        spi_data = 1;
        #10
        spi_clk = 1;
        #10
        spi_clk = 0;
        /*
        spi_data = 1;
        #10
        spi_clk = 1;
        #10
        spi_clk = 0;
        spi_data = 1;
        #10
        spi_clk = 1;
        #10
        spi_clk = 0;
        spi_data = 1;
        #10
        spi_clk = 1;
        #10
        */

        // Lower freq_cs. Should cause freq to be loaded into the phase acc
        freq_cs = 0;
        #10
        $display("waveform_out %h", waveform_out);
    end
endmodule