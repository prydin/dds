module dds 
    #(parameter ACC_LENGTH = 48, 
    parameter PHASE_LENGTH = 14
    ) (
        input sys_clk, 
        input spi_clk,
        input spi_data,
        input freq_cs,
        input phaseshift_cs,
        input [1:0] mode_in,
        output [PHASE_LENGTH-1:0] waveform_out
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
        .LENGTH(PHASE_LENGTH)
    ) waveform_shaper (
        .phase(reduced_phase[PHASE_LENGTH-1:0]),
        .mode(mode_in[1:0]),
        .out(waveform_out[PHASE_LENGTH-1:0])
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
    parameter LENGTH=14
    ) (
        input [LENGTH-1:0] phase,
        input [1:0] mode,
        output reg [LENGTH-1:0] out
    );


    always @(phase) begin
        case(mode)
            2'b00: assign out = phase; // Ramp
            2'b01: assign out = 0; // TODO: Triangle 
            2'b10: assign out = 0; // TODO: Sine lookup table
        endcase
    end
endmodule

module phase_acc #( 
        parameter ACC_LENGTH = 48,
        parameter OUT_LENGTH = 14
   ) (
    input clk,// System clock
    input [ACC_LENGTH-1:0] increment,    // Phase register increment per clock cycle
    input load_increment,               // Load internal register from increment bits (positive edge)
    input [OUT_LENGTH-1:0] phaseshift,  // Phaseshift
    input load_phaseshift,              // Load internal register from phaseshift bits (positive edge)
    output[OUT_LENGTH-1:0] out          // Phase output register
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
        acc <=  acc + increment_reg;
        $display("Acc: %h", acc);
    end

    // Reduce to 14 bits and add phase shift
    assign out[OUT_LENGTH-1:0] = acc[ACC_LENGTH - OUT_LENGTH - 1:0] + phaseshift_reg;
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
    