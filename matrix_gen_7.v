`timescale 1ns/1ns
module matrix_gen_7
#(
    parameter [9:0] IMG_HDISP = 10'd640,   // 图像水平分辨率
    parameter [9:0] IMG_VDISP = 10'd480    // 图像垂直分辨率
)
(
    input               clk,
    input               rst_n,

    // 输入二值化信号
    input               per_frame_vsync,
    input               per_frame_href,
    input               per_frame_clken,
    input               per_img_Bit,

    // 输出矩阵
    output reg          matrix_frame_vsync,
    output reg          matrix_frame_href,
    output reg          matrix_frame_clken,
    output reg [6:0]    matrix [0:6]       // 7x7 矩阵，每行7bit
);

////----- 1. 当前行寄存器 (row7) -----////
reg row7_data;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        row7_data <= 1'b0;
    else if (per_frame_clken)
        row7_data <= per_img_Bit;
end

////----- 2. 行缓存 -----////
wire row1_data, row2_data, row3_data, row4_data, row5_data, row6_data;
wire shift_clk_en = per_frame_clken;

// 第6行缓存
Line_Shift_RAM_1Bit #(.RAM_Length(IMG_HDISP)) u_row6 (
    .clock(clk),
    .clken(shift_clk_en),
    .shiftin(row7_data),
    .taps0x(row6_data),
    .taps1x(),
    .shiftout()
);

// 第5行缓存
Line_Shift_RAM_1Bit #(.RAM_Length(IMG_HDISP)) u_row5 (
    .clock(clk),
    .clken(shift_clk_en),
    .shiftin(row6_data),
    .taps0x(row5_data),
    .taps1x(),
    .shiftout()
);

// 第4行缓存
Line_Shift_RAM_1Bit #(.RAM_Length(IMG_HDISP)) u_row4 (
    .clock(clk),
    .clken(shift_clk_en),
    .shiftin(row5_data),
    .taps0x(row4_data),
    .taps1x(),
    .shiftout()
);

// 第3行缓存
Line_Shift_RAM_1Bit #(.RAM_Length(IMG_HDISP)) u_row3 (
    .clock(clk),
    .clken(shift_clk_en),
    .shiftin(row4_data),
    .taps0x(row3_data),
    .taps1x(),
    .shiftout()
);

// 第2行缓存
Line_Shift_RAM_1Bit #(.RAM_Length(IMG_HDISP)) u_row2 (
    .clock(clk),
    .clken(shift_clk_en),
    .shiftin(row3_data),
    .taps0x(row2_data),
    .taps1x(),
    .shiftout()
);

// 第1行缓存
Line_Shift_RAM_1Bit #(.RAM_Length(IMG_HDISP)) u_row1 (
    .clock(clk),
    .clken(shift_clk_en),
    .shiftin(row2_data),
    .taps0x(row1_data),
    .taps1x(),
    .shiftout()
);

////----- 3. 同步信号延迟 2 周期 -----////
reg [1:0] per_frame_vsync_r, per_frame_href_r, per_frame_clken_r;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        per_frame_vsync_r <= 0;
        per_frame_href_r  <= 0;
        per_frame_clken_r <= 0;
    end else begin
        per_frame_vsync_r <= {per_frame_vsync_r[0], per_frame_vsync};
        per_frame_href_r  <= {per_frame_href_r[0],  per_frame_href};
        per_frame_clken_r <= {per_frame_clken_r[0], per_frame_clken};
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        matrix_frame_vsync <= 0;
        matrix_frame_href  <= 0;
        matrix_frame_clken <= 0;
    end else begin
        matrix_frame_vsync <= per_frame_vsync_r[1];
        matrix_frame_href  <= per_frame_href_r[1];
        matrix_frame_clken <= per_frame_clken_r[1];
    end
end

////----- 4. 矩阵水平移位 -----////
integer r;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (r = 0; r < 7; r = r + 1)
            matrix[r] <= 7'b0;
    end else if (per_frame_href_r[0] && per_frame_clken_r[0]) begin
        matrix[0] <= {matrix[0][5:0], row1_data};
        matrix[1] <= {matrix[1][5:0], row2_data};
        matrix[2] <= {matrix[2][5:0], row3_data};
        matrix[3] <= {matrix[3][5:0], row4_data};
        matrix[4] <= {matrix[4][5:0], row5_data};
        matrix[5] <= {matrix[5][5:0], row6_data};
        matrix[6] <= {matrix[6][5:0], row7_data};
    end else if (!per_frame_href_r[0]) begin
        for (r = 0; r < 7; r = r + 1)
            matrix[r] <= 7'b0;
    end
end

endmodule
