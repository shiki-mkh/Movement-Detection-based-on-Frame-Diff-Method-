`timescale 1ns/1ns
module VIP_Bit_Dilation_7x7
#(
    parameter   [9:0]   IMG_HDISP = 10'd640,   // 图像水平分辨率
    parameter   [9:0]   IMG_VDISP = 10'd480    // 图像垂直分辨率
)
(
    input               clk,
    input               rst_n,

    // === 输入来自上游 Erosion 模块 ===
    input               erosion_vsync,     // 腐蚀后图像行同步信号
    input               erosion_href,      // 腐蚀后图像帧同步信号
    input               erosion_clken,     // 腐蚀后图像数据有效信号
    input               erosion_img_Bit,   // 腐蚀后图像像素

    // === 输出膨胀后的信号 ===
    output              dilation_vsync,    // 膨胀后图像行同步信号
    output              dilation_href,     // 膨胀后图像帧同步信号
    output              dilation_clken,    // 膨胀后图像数据有效信号
    output              dilation_img_Bit   // 膨胀后图像像素
);

////----- 1. 生成 7x7 矩阵 -----////
wire            matrix_frame_vsync;
wire            matrix_frame_href;
wire            matrix_frame_clken;
wire [6:0]      matrix [0:6];

matrix_gen_7  #(
    .IMG_HDISP  (IMG_HDISP),
    .IMG_VDISP  (IMG_VDISP)
)
u_matrix_gen_7(
    .clk                (clk),
    .rst_n              (rst_n),

    .per_frame_vsync    (erosion_vsync),
    .per_frame_href     (erosion_href),
    .per_frame_clken    (erosion_clken),
    .per_img_Bit        (erosion_img_Bit),

    .matrix_frame_vsync (matrix_frame_vsync),
    .matrix_frame_href  (matrix_frame_href),
    .matrix_frame_clken (matrix_frame_clken),
    .matrix             (matrix)
);

////----- 2. 膨胀运算（7x7 全部 OR，分两级） -----////
reg [6:0] row_or;      
reg       dilation_bit;

// 第一级：每行 OR
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        row_or <= 7'b0;
    else begin
        row_or[0] <= |matrix[0];
        row_or[1] <= |matrix[1];
        row_or[2] <= |matrix[2];
        row_or[3] <= |matrix[3];
        row_or[4] <= |matrix[4];
        row_or[5] <= |matrix[5];
        row_or[6] <= |matrix[6];
    end
end

// 第二级：行间 OR
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        dilation_bit <= 1'b0;
    else
        dilation_bit <= |row_or;  
end

////----- 3. 同步信号延迟两拍对齐 -----////
reg [1:0] vsync_r, href_r, clken_r;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        vsync_r <= 2'b0;
        href_r  <= 2'b0;
        clken_r <= 2'b0;
    end else begin
        vsync_r <= {vsync_r[0], matrix_frame_vsync};
        href_r  <= {href_r[0],  matrix_frame_href};
        clken_r <= {clken_r[0], matrix_frame_clken};
    end
end

assign dilation_vsync = vsync_r[1];
assign dilation_href  = href_r[1];
assign dilation_clken = clken_r[1];
assign dilation_img_Bit = dilation_href ? dilation_bit : 1'b0;

endmodule
