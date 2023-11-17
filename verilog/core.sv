module dds 
    #(parameter ACC_LENGTH = 48, 
    parameter PHASE_LENGTH = 16,
    parameter OUT_LENGTH = 16
    ) (
        input sys_clk, 
        input spi_clk,
        input spi_data,
        input freq_cs,
        input phaseshift_cs,
        input [1:0] mode_in,
        output [OUT_LENGTH-1:0] waveform_out
    );

    wire [ACC_LENGTH-1:0] freq_in;
    wire [PHASE_LENGTH-1:0] phaseshift_in;
    wire [PHASE_LENGTH-1:0] reduced_phase;
    wire freq_ready;
    wire phaseshift_ready;

    // Hook up register load to low flank on respective cs
    synched_load freq_load(sys_clk, freq_cs, freq_ready);
    synched_load phaseshift_load(sys_clk, phaseshift_cs, phaseshift_ready);


    // Shift registers to handle SPI communication
    // Frequency register
    shiftreg #(  
        .LENGTH(ACC_LENGTH)
    ) freq_spi (
        .clk(spi_clk), 
        .cs(freq_cs), 
        .d(spi_data), 
        .out(freq_in[ACC_LENGTH-1:0])
    );

    // Phase shift register
    shiftreg #( 
        .LENGTH(PHASE_LENGTH)
    ) phaseshift_spi (
        .clk(spi_clk), 
        .cs(phaseshift_cs), 
        .d(spi_data), 
        .out(phaseshift_in[PHASE_LENGTH-1:0])
    );

    // Phase accumulator
    phase_acc #(
        .ACC_LENGTH(ACC_LENGTH), 
        .OUT_LENGTH(PHASE_LENGTH)
    ) phase_acc (
        .clk(sys_clk),                          
        .increment(freq_in),                   
        .load_increment(freq_ready),            
        .phaseshift(phaseshift_in),             
        .load_phaseshift(phaseshift_ready),     
        .out(reduced_phase)
    );

    // Waveform shaper
    waveform_shaper #(
        .PHASE_LENGTH(PHASE_LENGTH),
        .OUT_LENGTH(OUT_LENGTH)
    ) waveform_shaper (
        .phase(reduced_phase),
        .mode(mode_in[1:0]),
        .out(waveform_out)
    );
endmodule

// Helper module to make sure that dds registers are always loaded on the negative flank
// of the system clock.
module synched_load(
    input clk,
    input trigger, // Negative edge
    output reg load
);

    reg should_load;

   always @(negedge clk) begin
        if(should_load) begin 
            $display("Loading activated");
            load <= 1;
            should_load <= 0;
        end
        else load <= 0;
    end

    always @(negedge trigger) begin
        should_load = 1;
        $display("Trigger activated");
    end
endmodule


module waveform_shaper #(
    parameter PHASE_LENGTH=16,
    parameter OUT_LENGTH=14
    ) (
        input [PHASE_LENGTH-1:0] phase,
        input [1:0] mode,
        output [OUT_LENGTH-1:0] out
    );

    // Waveform lookup tables
    localparam TABLE_SIZE = 2**PHASE_LENGTH;
    reg [OUT_LENGTH-1:0] sine[TABLE_SIZE];
    reg [OUT_LENGTH-1:0] triangle[TABLE_SIZE];

    initial begin
        $readmemh("sin-16-14.mem", sine);
        $readmemh("tri-16-14.mem", triangle);
    end

    assign out = translate(phase);

    function [OUT_LENGTH-1:0] translate(input [PHASE_LENGTH-1:0] phase);
        case(mode)
            2'b00: translate = phase;              // Ramp
            2'b01: translate = triangle[phase];    // Triangle
            2'b10: translate = sine[phase];        // Sine
            default: translate = 0;             
        endcase
    endfunction
endmodule

module phase_acc #( 
        parameter ACC_LENGTH = 48,
        parameter OUT_LENGTH = 16
   ) (
    input clk,// System clock
    input [ACC_LENGTH-1:0] increment,   // Phase register increment per clock cycle
    input load_increment,               // Load internal register from increment bits (positive edge)
    input [OUT_LENGTH-1:0] phaseshift,  // Phaseshift
    input load_phaseshift,              // Load internal register from phaseshift bits (positive edge)
    output reg [OUT_LENGTH-1:0] out     // Phase output register
);
    reg [ACC_LENGTH-1:0] acc;
    reg [ACC_LENGTH-1:0] increment_reg;
    reg [OUT_LENGTH-1:0] phaseshift_reg;

    initial begin
        acc = 0;
        increment_reg = 0;
        phaseshift_reg = 0;
    end

    // Load increment and phaseshift registers when their respective load line goes high
    always @(posedge load_increment) increment_reg = increment;
    always @(posedge load_phaseshift) phaseshift_reg = phaseshift;

    // Calculate the new value on positive clock
    always @(posedge clk) begin
        acc = acc + increment_reg;
        out = acc[ACC_LENGTH - 1:ACC_LENGTH - OUT_LENGTH] + phaseshift_reg;
    end

    // Reduce to output phase length and add phase shift
    // assign out =
endmodule

module shiftreg #( 
        parameter LENGTH = 48
   ) (
        input clk,
        input cs,
        input d,
        output reg [LENGTH-1:0] out
    );

    initial begin
        out = 0;
    end
    
    integer i;
    
    always @(posedge clk) begin 
        if (cs) begin
            for(i = 1; i < LENGTH; i = i + 1) begin
                out[i] <= out[i - 1];
            end
            out[0] <= d;
        end
    end
endmodule
    