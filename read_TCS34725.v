module read_TCS34725 (
    input wire clk,
    input wire rst,
    inout wire i2c_sda,
    inout wire i2c_scl,
    output reg [15:0] red,
    output reg [15:0] green,
    output reg [15:0] blue
);

    // FSM states
    localparam S_INIT_ENABLE = 0,
               S_INIT_WRITE  = 1,
               S_INIT_WAIT   = 2,
               S_SET_CMD     = 3,
               S_CMD_WAIT    = 4,
               S_READ_START  = 5,
               S_READ_WAIT   = 6,
               S_UPDATE      = 7;

    reg [3:0] state = S_INIT_ENABLE;
    reg [2:0] byte_count = 0;

    reg [6:0] dev_addr = 7'h29;  // I2C address of TCS34725
    reg [7:0] data_in_i2c = 0;
    reg rw_i2c = 0;              // 0 = write, 1 = read
    reg enable_i2c = 0;
    wire [7:0] data_out_i2c;
    wire ready_i2c;

    reg [7:0] rgb_data[0:5];     // RED_L, RED_H, GREEN_L, GREEN_H, BLUE_L, BLUE_H

    i2c_controller i2c_inst (
        .clk(clk),
        .rst(rst),
        .addr(dev_addr),
        .data_in(data_in_i2c),
        .enable(enable_i2c),
        .rw(rw_i2c),
        .data_out(data_out_i2c),
        .ready(ready_i2c),
        .i2c_sda(i2c_sda),
        .i2c_scl(i2c_scl)
    );

    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= S_INIT_ENABLE;
            enable_i2c <= 0;
            rw_i2c <= 0;
            byte_count <= 0;
            red <= 0;
            green <= 0;
            blue <= 0;
        end else begin
            case (state)

                // Step 1: Write to ENABLE register
                S_INIT_ENABLE: begin
                    if (ready_i2c) begin
                        data_in_i2c <= 8'h80; // CMD | ADDR = ENABLE (0x00)
                        rw_i2c <= 0;
                        enable_i2c <= 1;
                        state <= S_INIT_WRITE;
                    end
                end

                S_INIT_WRITE: begin
                    enable_i2c <= 0;
                    if (ready_i2c) begin
                        data_in_i2c <= 8'h03; // PON + AEN
                        enable_i2c <= 1;
                        state <= S_INIT_WAIT;
                    end
                end

                S_INIT_WAIT: begin
                    enable_i2c <= 0;
                    if (ready_i2c) begin
                        state <= S_SET_CMD;
                    end
                end

                // Step 2: Set Command Register for auto-increment from 0x14
                S_SET_CMD: begin
                    if (ready_i2c) begin
                        data_in_i2c <= 8'hB4; // CMD(1) | TYPE(01) | ADDR(0x14) = 0x80 | 0x20 | 0x14
                        rw_i2c <= 0;
                        enable_i2c <= 1;
                        state <= S_CMD_WAIT;
                    end
                end

                S_CMD_WAIT: begin
                    enable_i2c <= 0;
                    if (ready_i2c) begin
                        rw_i2c <= 1;          // Switch to read mode
                        enable_i2c <= 1;
                        byte_count <= 0;
                        state <= S_READ_START;
                    end
                end

                // Step 3: Read 6 bytes sequentially
                S_READ_START: begin
                    enable_i2c <= 0;
                    if (ready_i2c) begin
                        enable_i2c <= 1;     // Start reading first byte
                        state <= S_READ_WAIT;
                    end
                end

                S_READ_WAIT: begin
                    enable_i2c <= 0;
                    if (ready_i2c) begin
                        rgb_data[byte_count] <= data_out_i2c;
                        byte_count <= byte_count + 1;
                        if (byte_count < 5) begin
                            enable_i2c <= 1; // Read next byte
                        end else begin
                            state <= S_UPDATE;
                        end
                    end
                end

                // Step 4: Update RGB values
                S_UPDATE: begin
                    red   <= {rgb_data[1], rgb_data[0]};
                    green <= {rgb_data[3], rgb_data[2]};
                    blue  <= {rgb_data[5], rgb_data[4]};
                    state <= S_SET_CMD; // Loop back to keep reading
                end
            endcase
        end
    end

endmodule
