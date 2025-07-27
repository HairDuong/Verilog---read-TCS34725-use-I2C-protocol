module read_TCS34725 (
    input wire clk,
    input wire rst,
    output wire i2c_scl,
    inout wire i2c_sda,
    output reg [15:0] red,
    output reg [15:0] green,
    output reg [15:0] blue,
    output reg [15:0] clear
);

    // I2C signals
    reg [6:0] i2c_addr;
    reg [7:0] i2c_data_in;
    reg i2c_enable;
    reg i2c_rw;
    wire [7:0] i2c_data_out;
    wire i2c_ready;

    // FSM state
// Định nghĩa các trạng thái bằng parameter
parameter S_IDLE           = 5'd0,
          S_WRITE_ENABLE1  = 5'd1,
          S_WRITE_ENABLE2  = 5'd2,
          S_WRITE_ATIME1   = 5'd3,
          S_WRITE_ATIME2   = 5'd4,
          S_WRITE_WTIME1   = 5'd5,
          S_WRITE_WTIME2   = 5'd6,
          S_SEND_CMD_READ  = 5'd7,
          S_READ_WAIT      = 5'd8,
          S_READ_CLR_L     = 5'd9,
          S_READ_CLR_H     = 5'd10,
          S_READ_RED_L     = 5'd11,
          S_READ_RED_H     = 5'd12,
          S_READ_GREEN_L   = 5'd13,
          S_READ_GREEN_H   = 5'd14,
          S_READ_BLUE_L    = 5'd15,
          S_READ_BLUE_H    = 5'd16;

// Biến trạng thái
reg [4:0] state;


    // I2C controller instance
    i2c_controller i2c_inst (
        .clk(clk),
        .rst(rst),
        .addr(i2c_addr),
        .data_in(i2c_data_in),
        .enable(i2c_enable),
        .rw(i2c_rw),
        .data_out(i2c_data_out),
        .ready(i2c_ready),
        .i2c_scl(i2c_scl),
        .i2c_sda(i2c_sda)
    );

    // FSM
    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            state <= S_IDLE;
            i2c_enable <= 0;
            i2c_rw <= 0;
            i2c_addr <= 7'h29; // 7-bit I2C address
            clear <= 0; red <= 0; green <= 0; blue <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (i2c_ready) begin
                        i2c_data_in <= 8'h80; // CMD | 0x00 (ENABLE reg)
                        i2c_rw <= 0;
                        i2c_enable <= 1;
                        state <= S_WRITE_ENABLE1;
                    end
                end
                S_WRITE_ENABLE1: begin
                    i2c_enable <= 0;
                    if (i2c_ready) begin
                        i2c_data_in <= 8'h0B; // PON | AEN | WEN
                        i2c_enable <= 1;
                        state <= S_WRITE_ENABLE2;
                    end
                end
                S_WRITE_ENABLE2: begin
                    i2c_enable <= 0;
                    if (i2c_ready) begin
                        i2c_data_in <= 8'h81; // CMD | 0x01 (ATIME)
                        i2c_enable <= 1;
                        state <= S_WRITE_ATIME1;
                    end
                end
                S_WRITE_ATIME1: begin
                    i2c_enable <= 0;
                    if (i2c_ready) begin
                        i2c_data_in <= 8'hFF; // ATIME = 256 - 1 = max
                        i2c_enable <= 1;
                        state <= S_WRITE_ATIME2;
                    end
                end
                S_WRITE_ATIME2: begin
                    i2c_enable <= 0;
                    if (i2c_ready) begin
                        i2c_data_in <= 8'h83; // CMD | 0x03 (WTIME)
                        i2c_enable <= 1;
                        state <= S_WRITE_WTIME1;
                    end
                end
                S_WRITE_WTIME1: begin
                    i2c_enable <= 0;
                    if (i2c_ready) begin
                        i2c_data_in <= 8'hFF; // WTIME = max
                        i2c_enable <= 1;
                        state <= S_WRITE_WTIME2;
                    end
                end
                S_WRITE_WTIME2: begin
                    i2c_enable <= 0;
                    if (i2c_ready) begin
                        i2c_data_in <= 8'h94; // CMD | Auto-Inc | 0x14
                        i2c_rw <= 0;
                        i2c_enable <= 1;
                        state <= S_SEND_CMD_READ;
                    end
                end
                S_SEND_CMD_READ: begin
                    i2c_enable <= 0;
                    if (i2c_ready) begin
                        i2c_rw <= 1; // switch to read mode
                        i2c_enable <= 1;
                        state <= S_READ_CLR_L;
                    end
                end
                S_READ_CLR_L: begin
                    i2c_enable <= 0;
                    if (i2c_ready) begin
                        clear[7:0] <= i2c_data_out;
                        i2c_enable <= 1;
                        state <= S_READ_CLR_H;
                    end
                end
                S_READ_CLR_H: begin
                    i2c_enable <= 0;
                    if (i2c_ready) begin
                        clear[15:8] <= i2c_data_out;
                        i2c_enable <= 1;
                        state <= S_READ_RED_L;
                    end
                end
                S_READ_RED_L: begin
                    i2c_enable <= 0;
                    if (i2c_ready) begin
                        red[7:0] <= i2c_data_out;
                        i2c_enable <= 1;
                        state <= S_READ_RED_H;
                    end
                end
                S_READ_RED_H: begin
                    i2c_enable <= 0;
                    if (i2c_ready) begin
                        red[15:8] <= i2c_data_out;
                        i2c_enable <= 1;
                        state <= S_READ_GREEN_L;
                    end
                end
                S_READ_GREEN_L: begin
                    i2c_enable <= 0;
                    if (i2c_ready) begin
                        green[7:0] <= i2c_data_out;
                        i2c_enable <= 1;
                        state <= S_READ_GREEN_H;
                    end
                end
                S_READ_GREEN_H: begin
                    i2c_enable <= 0;
                    if (i2c_ready) begin
                        green[15:8] <= i2c_data_out;
                        i2c_enable <= 1;
                        state <= S_READ_BLUE_L;
                    end
                end
                S_READ_BLUE_L: begin
                    i2c_enable <= 0;
                    if (i2c_ready) begin
                        blue[7:0] <= i2c_data_out;
                        i2c_enable <= 1;
                        state <= S_READ_BLUE_H;
                    end
                end
                S_READ_BLUE_H: begin
                    i2c_enable <= 0;
                    if (i2c_ready) begin
                        blue[15:8] <= i2c_data_out;
                        i2c_enable <= 0;
                        state <= S_WRITE_ENABLE1; // quay lại đọc tiếp
                    end
                end
            endcase
        end
    end
endmodule