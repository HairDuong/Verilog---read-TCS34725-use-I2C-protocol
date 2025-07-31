module color_detector (
    input wire clk,
    input wire rst,
    input wire [15:0] clear,
    input wire [15:0] red,
    input wire [15:0] green,
    input wire [15:0] blue,
    input wire data_valid,

    output reg is_blue,
    output reg is_green,
    output reg is_red,
    output reg is_unknown
);

    // Ngưỡng tỷ lệ phần trăm (0–100)
    localparam RED_DOMINANT   = 70;
    localparam GREEN_DOMINANT = 70;
    localparam BLUE_DOMINANT  = 70;
    localparam COLOR_THRESH   = 30;  // Ngưỡng phụ cho kênh không chiếm ưu thế
    localparam CLEAR_MIN      = 16'h0030; // Tối thiểu để phân biệt màu

    // Tính phần trăm từng màu so với Clear
    wire [15:0] red_ratio   = (red   * 100) / (clear + 1); // +1 để tránh chia 0
    wire [15:0] green_ratio = (green * 100) / (clear + 1);
    wire [15:0] blue_ratio  = (blue  * 100) / (clear + 1);

    always @(posedge clk or negedge rst) begin
        if (~rst) begin
            is_red     <= 0;
            is_green   <= 0;
            is_blue    <= 0;
            is_unknown <= 0;
        end else if (data_valid) begin
            // Reset outputs trước
            is_red     <= 0;
            is_green   <= 0;
            is_blue    <= 0;
            is_unknown <= 0;

				if (blue == green && green > red)
				is_blue <= 1;
				else if (green > red && red > blue)
				is_green <= 1;
				else if (red > green && green > blue)
				is_red <= 1;
				else
				is_unknown <= 1;
		
            end
        end

endmodule
