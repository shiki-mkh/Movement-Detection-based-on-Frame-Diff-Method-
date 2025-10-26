`timescale 1ns/1ns
module Erosion_5x5
#(
    parameter   [9:0]   IMG_HDISP = 10'd640,   // 图像水平分辨率
    parameter   [9:0]   IMG_VDISP = 10'd480    // 图像垂直分辨率
)
(
    input               clk,                    // 像素时钟
    input               rst_n,                  // 异步复位

    input               binarize_vsync,         // 行同步信号
    input               binarize_href,          // 帧同步信号
    input               binarize_clken,         // 数据有效信号
    input               binarize_img_Bit,       // 二值化图像像素 (1:有效, 0:无效)
    
    output              erosion_vsync,          // 腐蚀后图像行同步信号
    output              erosion_href,           // 腐蚀后图像帧同步信号
    output              erosion_clken,          // 腐蚀后图像数据有效信号
    output              erosion_img_Bit         // 腐蚀后图像像素
);

////----- 1. 生成 5*5 矩阵模块 -----////
wire            matrix_frame_vsync;
wire            matrix_frame_href;
wire            matrix_frame_clken;
wire [4:0]      matrix [0:4];    // 5x5 矩阵

matrix_gen_5    
#(
    .IMG_HDISP  (IMG_HDISP)
)
u_matrix_gen_5
(
    .clk                (clk),
    .rst_n              (rst_n),

    // 输入信号
    .per_frame_vsync    (binarize_vsync),
    .per_frame_href     (binarize_href),
    .per_frame_clken    (binarize_clken),
    .per_img_Bit        (binarize_img_Bit),

    // 输出 5x5 矩阵
    .matrix_frame_vsync (matrix_frame_vsync),
    .matrix_frame_href  (matrix_frame_href),
    .matrix_frame_clken (matrix_frame_clken),
    .matrix             (matrix)
);

////----- 2. 腐蚀运算 -----////
reg [4:0] row_and;    // 每行5bit的与
reg erosion_bit;      // 最终腐蚀结果

// 第一级：行内与
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        row_and <= 5'b0;
    else begin
        row_and[0] <= &matrix[0];
        row_and[1] <= &matrix[1];
        row_and[2] <= &matrix[2];
        row_and[3] <= &matrix[3];
        row_and[4] <= &matrix[4];
    end
end

// 第二级：行间与
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        erosion_bit <= 1'b0;
    else
        erosion_bit <= &row_and;  
end

////----- 3. 信号同步延迟（两级，保持对齐） -----////
reg [1:0] vsync_r;
reg [1:0] href_r;    
reg [1:0] clken_r;

always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        vsync_r <= 0;
        href_r  <= 0;
        clken_r <= 0;
    end else begin
        vsync_r <= {vsync_r[0], matrix_frame_vsync};
        href_r  <= {href_r[0],  matrix_frame_href};
        clken_r <= {clken_r[0], matrix_frame_clken};
    end
end

assign erosion_vsync = vsync_r[1];
assign erosion_href  = href_r[1];
assign erosion_clken = clken_r[1];
assign erosion_img_Bit = erosion_href ? erosion_bit : 1'b0;

endmodule
