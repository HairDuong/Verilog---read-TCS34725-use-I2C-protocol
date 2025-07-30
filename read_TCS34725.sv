module read_TCS34725 (
    input wire clk,          // 12MHz system clock
    input wire rst,          // Active low reset
    inout wire i2c_scl,      // I2C clock
    inout wire i2c_sda,      // I2C data
    output reg [7:0] red,    // Red high byte only
    output reg [7:0] green,  // Green high byte only
    output reg [7:0] blue,   // Blue high byte only
    output reg [7:0] clear   // Clear high byte only
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

    // FSM states
    typedef enum logic [3:0] {
        S_IDLE,
        S_WRITE_ENABLE,
        S_WAIT_PON,
        S_WRITE_ATIME,
        S_WAIT_INTEGRATION,
        S_READ_CLEAR_H,
        S_READ_RED_H,
        S_READ_GREEN_H,
        S_READ_BLUE_H,
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

    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            state <= S_IDLE;
            enable <= 0;
            red <= 0;
            green <= 0;
            blue <= 0;
            clear <= 0;
            delay_counter <= 0;
        end else begin
            enable <= 0; // Default disable
            
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
                        delay_counter <= 24'd28_800; // Wait integration time
                        state <= S_WAIT_INTEGRATION;
                    end
                end
                
                S_WAIT_INTEGRATION: begin
                    if (delay_counter > 0) begin
                        delay_counter <= delay_counter - 1;
                    end else if (!busy) begin
                        // Read Clear High Byte
                        register_address <= 8'h94; // CDATAH reg (0x15 | 0x80)
                        read_write <= 1;
                        enable <= 1;
                        state <= S_READ_CLEAR_H;
                    end
                end
                
                S_READ_CLEAR_H: begin
                    if (!busy && !enable) begin
                        clear <= miso_data;
                        
                        // Read Red High Byte
                        register_address <= 8'h96; // RDATAH reg (0x17 | 0x80)
                        read_write <= 1;
                        enable <= 1;
                        state <= S_READ_RED_H;
                    end
                end
                
                S_READ_RED_H: begin
                    if (!busy && !enable) begin
                        red <= miso_data;
                        
                        // Read Green High Byte
                        register_address <= 8'h98; // GDATAH reg (0x19 | 0x80)
                        read_write <= 1;
                        enable <= 1;
                        state <= S_READ_GREEN_H;
                    end
                end
                
                S_READ_GREEN_H: begin
                    if (!busy && !enable) begin
                        green <= miso_data;
                        
                        // Read Blue High Byte
                        register_address <= 8'h9A; // BDATAH reg (0x1B | 0x80)
                        read_write <= 1;
                        enable <= 1;
                        state <= S_READ_BLUE_H;
                    end
                end
                
                S_READ_BLUE_H: begin
                    if (!busy && !enable) begin
                        blue <= miso_data;
                        state <= S_DONE;
                    end
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