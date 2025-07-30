module color_detector (
    input wire clk,
    input wire rst,
    input wire [15:0] clear,
    input wire [15:0] red,
    input wire [15:0] green,
    input wire [15:0] blue,
    input wire data_valid,
    
    // Output GPIOs - phải là reg vì gán trong always block
    output reg is_blue, is_green, is_red, is_unknown
);

// Định nghĩa các ngưỡng giá trị từ dữ liệu thực tế
localparam CLEAR_THRESH = 16'h00F0;  // Fh
localparam HIGH_THRESH  = 16'h0070;  // 7h
localparam MID_THRESH   = 16'h0030;  // 3h
localparam LOW_THRESH   = 16'h0010;  // 1h

// Biến tạm để tính toán trước khi gán
reg tmp_red, tmp_green, tmp_blue;

always @(posedge clk or negedge rst) begin
    if (~rst) begin
        is_red <= 0;
        is_green <= 0;
        is_blue <= 0;
        is_unknown <= 0;
    end else if (data_valid) begin
        // Tính toán các giá trị tạm trước
        tmp_green = (green >= HIGH_THRESH) && 
                   (blue >= MID_THRESH) && 
                   (red < MID_THRESH) && 
                   (clear >= CLEAR_THRESH);
        
        tmp_red = (red >= HIGH_THRESH) && 
                 (green < MID_THRESH) && 
                 (blue < MID_THRESH) && 
                 (clear >= CLEAR_THRESH);
        
        tmp_blue = (blue >= HIGH_THRESH) && 
                  (green >= HIGH_THRESH) && 
                  (red < MID_THRESH) && 
                  (clear >= CLEAR_THRESH);
        
        // Gán giá trị output
        is_green <= tmp_green;
        is_red <= tmp_red;
        is_blue <= tmp_blue;
        is_unknown <= ~(tmp_red | tmp_green | tmp_blue) && 
                     (clear >= MID_THRESH);
    end
end
endmodule