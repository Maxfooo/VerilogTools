// Analog In_0: 24
// ADC_CS_N: A10
// ADC_SADDR: B10
// ADC_SDAT: A9
// ADC_SCLK: B14
// Resource: ftp://ftp.altera.com/up/pub/Altera_Material/12.1/Tutorials/DE0-Nano/Using_DE0-Nano_ADC.pdf
// ADC: http://www.ti.com/lit/ds/symlink/adc128s022.pdf

// Created: Max Ruiz, 1 June 2016
// Modified: Max Ruiz, 8 June 2016 - Update address case statement, now it works on all channels
// Modified: Max Ruiz, 28 June 2016, Updated output independence

module DE0_ADC (
	clk_ad,
	adc_select,
	request,
	ready,
	ad_convert_read,
	
	// hardware connections, this block controls/ interfaces with them
	adc_sclk,
	adc_cs_n,
	adc_saddr,
	adc_sdat
);

parameter DATA_WIDTH = 12;
parameter ADC_SELECT_WIDTH = 3;
parameter DATA_CAPTURE_WIDTH = 16;

input clk_ad;																	// On chip clock (50MHz)
input [ADC_SELECT_WIDTH-1:0] adc_select; 								// channel width is always 3 bits
input request;																	// set high when requesting data
output ready;																	// This block will set "ready" when available for data conversion,
reg ready = 1'b1;																// and/or data is ready to be read
output [DATA_WIDTH + ADC_SELECT_WIDTH:0] ad_convert_read; 		// Converted data register + adc_select
reg [DATA_WIDTH + ADC_SELECT_WIDTH:0] ad_convert_read = {DATA_WIDTH + ADC_SELECT_WIDTH {1'b0}};

output adc_sclk;				// Sample Clock
wire adc_sclk;
assign adc_sclk = clk_ad;
output adc_cs_n;				// Chip select
reg adc_cs_n = 1'b1;
output adc_saddr;				// data address -> ADC channel address
reg adc_saddr = 1'b0;	
input adc_sdat;				// converted data bit from ADC


reg [7:0] data_state = 8'h00;
reg [ADC_SELECT_WIDTH-1:0] data_channel = {ADC_SELECT_WIDTH {1'b0}};
reg [DATA_CAPTURE_WIDTH-1:0] data_capture = {DATA_CAPTURE_WIDTH {1'b0}}; // 16
reg requestFF = 1'b0;


always @(posedge clk_ad) begin
	// On the final (16th) state, the converted data has been retrieved
	if (data_state == 8'h10) begin
		adc_cs_n <= 1'b1;
		ready <= 1'b1;
		data_state <= 8'h00;
		ad_convert_read <= {1'b0, data_channel, data_capture[11:0]};
		requestFF <= 1'b0;
	// On request from an outside controller, this block will
	// set the chip select and cache the channel address
	end else if (request == 1'b1 && requestFF == 1'b0) begin
		requestFF <= 1'b1;
		adc_cs_n <= 1'b0;
		ready <= 1'b0;
		data_channel <= adc_select;
		// MSB of ad_convert_read will always be 1'b0
	// Until state 16 is reached, the SM will loop here.
	// States 2,3,4 are when the ADC channel address is to
	// be transmitted.
	end else if (adc_cs_n == 1'b0) begin
		case (data_state)
			8'h01: begin
				adc_saddr <= data_channel[2];
			end
			8'h02: begin
				adc_saddr <= data_channel[1];
			end
			8'h03: begin
				adc_saddr <= data_channel[0];
			end
		endcase
		data_state <= data_state + 1'b1;
	end
end

// 16 state shift register to capture the bits
// coming from the ADC. The last four bits will be zero.
// This is inherent of the ADC, check the timing diagram in
// the data sheet if you would like proof.
always @(posedge clk_ad) begin
	if (adc_cs_n == 1'b0) begin
		data_capture <= data_capture << 1;
		data_capture[0] <= adc_sdat;
	end
end

endmodule
