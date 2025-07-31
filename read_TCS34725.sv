module read_TCS34725 (
    input wire clk,          // 12MHz system clock
    input wire rst,          // Active low reset
    inout wire i2c_scl,      // I2C clock
    inout wire i2c_sda,      // I2C data
    output reg [15:0] red,    // Red 16-bit data
    output reg [15:0] green,  // Green 16-bit data
    output reg [15:0] blue,   // Blue 16-bit data
    output reg [15:0] clear,  // Clear 16-bit data
    output reg data_valid ,    // Data valid strobe
	 
	 // Color detection outputs
    output reg is_red,      // Red detected
    output reg is_green,    // Green detected
    output reg is_blue,     // Blue detected
    output reg is_unknown   // Unknown color
);

    // I2C interface signals
    reg enable;
    reg read_write;          // 0 = write, 1 = read
    reg [6:0] device_address = 7'h29; // TCS34725 address
    reg [7:0] register_address;
    reg [7:0] mosi_data;
    wire [7:0] miso_data;
    wire busy;
    reg [23:0] delay_counter;
    reg [15:0] i2c_divider = 16'd30; // 100kHz at 12MHz

    // Temporary storage for 16-bit values
    reg [7:0] clear_l, clear_h;
    reg [7:0] red_l, red_h;
    reg [7:0] green_l, green_h;
    reg [7:0] blue_l, blue_h;

    // FSM states
    typedef enum logic [4:0] {
        S_IDLE,
        S_WRITE_ENABLE,
        S_WAIT_PON,
        S_WRITE_ATIME,
		  S_WRITE_GAIN,
        S_WAIT_INTEGRATION,
        S_READ_CLEAR_L,
        S_READ_CLEAR_H,
        S_READ_RED_L,
        S_READ_RED_H,
        S_READ_GREEN_L,
        S_READ_GREEN_H,
        S_READ_BLUE_L,
        S_READ_BLUE_H,
        S_UPDATE_OUTPUT,
        S_DONE
    } state_t;
    state_t state;

    // Instantiate I2C controller
    i2c_controller #(
        .NUMBER_OF_DATA_BYTES(1),
        .NUMBER_OF_REGISTER_BYTES(1),
        .ADDRESS_WIDTH(7),
        .CHECK_FOR_CLOCK_STRETCHING(1),
        .CLOCK_STRETCHING_MAX_COUNT(1000)
    ) i2c_master_inst (
        .clock(clk),
        .reset_n(rst),
        .enable(enable),
        .read_write(read_write),
        .device_address(device_address),
        .register_address(register_address),
        .divider(i2c_divider),
        .mosi_data(mosi_data),
        .miso_data(miso_data),
        .busy(busy),
        .external_serial_clock(i2c_scl),
        .external_serial_data(i2c_sda)
    );

	wire color_is_red, color_is_green, color_is_blue, color_is_unknown;

    // Instantiate color detector
    color_detector color_detect (
        .clk(clk),
        .rst(rst),
        .clear(clear),
        .red(red),
        .green(green),
        .blue(blue),
        .data_valid(data_valid),
        .is_blue(color_is_blue),
        .is_green(color_is_green),
        .is_red(color_is_red),
        .is_unknown(color_is_unknown)
    );
	 // Gán output
    assign is_red = color_is_red;
    assign is_green = color_is_green;
    assign is_blue = color_is_blue;
    assign is_unknown = color_is_unknown;

    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            state <= S_IDLE;
            enable <= 0;
            red <= 0;
            green <= 0;
            blue <= 0;
            clear <= 0;
            data_valid <= 0;
            delay_counter <= 0;
            // Reset temporary registers
            clear_l <= 0; clear_h <= 0;
            red_l <= 0; red_h <= 0;
            green_l <= 0; green_h <= 0;
            blue_l <= 0; blue_h <= 0;
        end else begin
            enable <= 0; // Default disable
            data_valid <= 0; // Default no valid data
            
            case (state)
                S_IDLE: begin
                    if (!busy) begin
                        // Enable sensor (PON + AEN)
                        register_address <= 8'h80; // ENABLE reg
                        mosi_data <= 8'h03;       // PON | AEN
                        read_write <= 0;
                        enable <= 1;
                        state <= S_WRITE_ENABLE;
                    end
                end
                
                S_WRITE_ENABLE: begin
                    if (!busy && !enable) begin
                        delay_counter <= 24'd28_800; // 2.4ms delay
                        state <= S_WAIT_PON;
                    end
                end
                
                S_WAIT_PON: begin
                    if (delay_counter > 0) begin
                        delay_counter <= delay_counter - 1;
                    end else begin
                        // Set integration time
                        register_address <= 8'h81; // ATIME reg
                        mosi_data <= 8'hFF;      // 2.4ms
                        read_write <= 0;
                        enable <= 1;
                        state <= S_WRITE_ATIME;
                    end
                end
                
                                S_WRITE_ATIME: begin
                    if (!busy && !enable) begin
                        // Set gain to 16x (0x02 to register 0x0F)
                        register_address <= 8'h8F; // CONTROL reg (0x0F + 0x80)
                        mosi_data <= 8'h02;       // AGAIN = 16x
                        read_write <= 0;
                        enable <= 1;
                        state <= S_WRITE_GAIN;
                    end
                end

                S_WRITE_GAIN: begin
                    if (!busy && !enable) begin
                        delay_counter <= 24'd28_800; // Wait integration time
                        state <= S_WAIT_INTEGRATION;
                    end
                end
                
                S_WAIT_INTEGRATION: begin
                    if (delay_counter > 0) begin
                        delay_counter <= delay_counter - 1;
                    end else if (!busy) begin
                        // Start reading sequence with Clear Low Byte
                        register_address <= 8'h94; // CDATAL reg (0x14 | 0x80)
                        read_write <= 1;
                        enable <= 1;
                        state <= S_READ_CLEAR_L;
                    end
                end
                
                S_READ_CLEAR_L: begin
                    if (!busy && !enable) begin
                        clear_l <= miso_data;
                        
                        // Read Clear High Byte
                        register_address <= 8'h95; // CDATAH reg (0x15 | 0x80)
                        read_write <= 1;
                        enable <= 1;
                        state <= S_READ_CLEAR_H;
                    end
                end
                
                S_READ_CLEAR_H: begin
                    if (!busy && !enable) begin
                        clear_h <= miso_data;
                        
                        // Read Red Low Byte
                        register_address <= 8'h96; // RDATAL reg (0x16 | 0x80)
                        read_write <= 1;
                        enable <= 1;
                        state <= S_READ_RED_L;
                    end
                end
                
                S_READ_RED_L: begin
                    if (!busy && !enable) begin
                        red_l <= miso_data;
                        
                        // Read Red High Byte
                        register_address <= 8'h97; // RDATAH reg (0x17 | 0x80)
                        read_write <= 1;
                        enable <= 1;
                        state <= S_READ_RED_H;
                    end
                end
                
                S_READ_RED_H: begin
                    if (!busy && !enable) begin
                        red_h <= miso_data;
                        
                        // Read Green Low Byte
                        register_address <= 8'h98; // GDATAL reg (0x18 | 0x80)
                        read_write <= 1;
                        enable <= 1;
                        state <= S_READ_GREEN_L;
                    end
                end
                
                S_READ_GREEN_L: begin
                    if (!busy && !enable) begin
                        green_l <= miso_data;
                        
                        // Read Green High Byte
                        register_address <= 8'h99; // GDATAH reg (0x19 | 0x80)
                        read_write <= 1;
                        enable <= 1;
                        state <= S_READ_GREEN_H;
                    end
                end
                
                S_READ_GREEN_H: begin
                    if (!busy && !enable) begin
                        green_h <= miso_data;
                        
                        // Read Blue Low Byte
                        register_address <= 8'h9A; // BDATAL reg (0x1A | 0x80)
                        read_write <= 1;
                        enable <= 1;
                        state <= S_READ_BLUE_L;
                    end
                end
                
                S_READ_BLUE_L: begin
                    if (!busy && !enable) begin
                        blue_l <= miso_data;
                        
                        // Read Blue High Byte
                        register_address <= 8'h9B; // BDATAH reg (0x1B | 0x80)
                        read_write <= 1;
                        enable <= 1;
                        state <= S_READ_BLUE_H;
                    end
                end
                
                S_READ_BLUE_H: begin
                    if (!busy && !enable) begin
                        blue_h <= miso_data;
                        state <= S_UPDATE_OUTPUT;
                    end
                end
                
                S_UPDATE_OUTPUT: begin
                    // Combine low and high bytes
                    clear <= {clear_h, clear_l};
                    red <= {red_h, red_l};
                    green <= {green_h, green_l};
                    blue <= {blue_h, blue_l};
                    data_valid <= 1; // Pulse valid signal
                    state <= S_DONE;
                end
                
                S_DONE: begin
                    // Prepare for next reading cycle
                    delay_counter <= 24'd28_800; // 2.4ms delay
                    state <= S_WAIT_INTEGRATION;
                end
            endcase
        end
    end
endmodule