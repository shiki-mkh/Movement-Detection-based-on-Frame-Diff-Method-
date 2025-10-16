
`timescale 1ns / 1ps
module IMGD_TOP #(
    parameter IMG_HDISP = 10'd640,
    parameter IMG_VDISP = 10'd480
)(
    input               clk,             // 系统时钟，建议 50MHz 或更高
    input               rst_n,           // 复位信号
    input                dvp_vsync,  //帧有效信号    
    input                dvp_href ,  //行有效信号
    input                dvp_valid,  //数据有效使能信号
    input       [15:0]   dvp_data,   //有效数据  

    // === 输出：带矩形标记的图像 ===
    output              post_frame_vsync,
    output              post_frame_href,
    output              post_frame_clken,
    output      [15:0]  post_img_Y,

    input  [15:0]  sys_data_out1,//sdram
	output         gs_clken ,
	output  [15:0] gray_sft ,
	output         sdr_rd 
	
    //thresould 设置为定值8'd30
);

    

    // =========================================================
    // 2. RGB 转灰度
    // =========================================================
    wire                gray_valid;
    wire                gray_vsync;
    wire                gray_href;
    wire        [7:0]   gray_data;

    rgb2gray u_rgb2gray (
        .clk            (ov5640_pclk),
        .rst_n          (rst_n),

        .dvp_vsync      (dvp_vsync),
        .dvp_href       (dvp_href),
        .dvp_valid      (dvp_valid),
        .dvp_data       (dvp_data),

        .gray_valid     (gray_valid),
        .gray_vsync     (gray_vsync),
        .gray_href      (gray_href),
        .gray_data      (gray_data)
    );

    // =========================================================
    // 3. 帧同步模块（两帧对齐）
    // =========================================================
    wire                sdr_rd;
    wire        [15:0]  ajct_gray;
    wire                ajct_vsync;
    wire                ajct_href;
    wire                ajct_clken;

   assign gs_clken = ajct_clken;
   assign gray_sft = ajct_gray;

    frame_adjacent_sync u_frame_adj_sync (
        .clk            (ov5640_pclk),
        .rst_n          (rst_n),

        .clken          (gray_valid),
        .gray_vsync     (gray_vsync),
        .gray_href      (gray_href),
        .gray_data      (gray_data),
        .gray_sdr       (sys_data_out1),   // TODO: 前一帧灰度图（待实际连接）
        
        .sdr_rd         (sdr_rd),
        .ajct_gray      (ajct_gray),
        .ajct_vsync     (ajct_vsync),
        .ajct_href      (ajct_href),
        .ajct_clken     (ajct_clken)
    );

    // =========================================================
    // 4. 帧差二值化
    // =========================================================
    wire                binarize_clken;
    wire                binarize_href;
    wire                binarize_vsync;
    wire                binarize_img_Bit;

    Binarization #(
        .THRESHOLD(8'd30)
    ) u_binarization (
        .clk                (ov5640_pclk),
        .rst_n              (rst_n),

        .ajct_clken         (ajct_clken),
        .ajct_href          (ajct_href),
        .ajct_vsync         (ajct_vsync),
        .ajct_gray          (ajct_gray),

        .binarize_clken     (binarize_clken),
        .binarize_href      (binarize_href),
        .binarize_vsync     (binarize_vsync),
        .binarize_img_Bit   (binarize_img_Bit)
    );

    // =========================================================
    // 5. 腐蚀 (Erosion 5x5)
    // =========================================================
    wire                erosion_vsync;
    wire                erosion_href;
    wire                erosion_clken;
    wire                erosion_img_Bit;

    Erosion_5x5 #(
        .IMG_HDISP(IMG_HDISP),
        .IMG_VDISP(IMG_VDISP)
    ) u_erosion (
        .clk                (ov5640_pclk),
        .rst_n              (rst_n),
        .binarize_vsync     (binarize_vsync),
        .binarize_href      (binarize_href),
        .binarize_clken     (binarize_clken),
        .binarize_img_Bit   (binarize_img_Bit),
        .erosion_vsync      (erosion_vsync),
        .erosion_href       (erosion_href),
        .erosion_clken      (erosion_clken),
        .erosion_img_Bit    (erosion_img_Bit)
    );

    // =========================================================
    // 6. 膨胀 (Dilation 7x7)
    // =========================================================
    wire                dilation_vsync;
    wire                dilation_href;
    wire                dilation_clken;
    wire                dilation_img_Bit;

    Dilation #(
        .IMG_HDISP(IMG_HDISP),
        .IMG_VDISP(IMG_VDISP)
    ) u_dilation (
        .clk                (ov5640_pclk),
        .rst_n              (rst_n),
        .erosion_vsync      (erosion_vsync),
        .erosion_href       (erosion_href),
        .erosion_clken      (erosion_clken),
        .erosion_img_Bit    (erosion_img_Bit),
        .dilation_vsync     (dilation_vsync),
        .dilation_href      (dilation_href),
        .dilation_clken     (dilation_clken),
        .dilation_img_Bit   (dilation_img_Bit)
    );

    // =========================================================
    // 7️⃣  rectangle 模块
    // =========================================================
    rectangle #(
        .IMG_WIDTH  (IMG_HDISP),
        .IMG_HEIGHT (IMG_VDISP)
    ) u_rectangle (
        .clk                (ov5640_pclk),
        .rst_n              (rst_n),

        // 检测到的二值图像（用于边界检测）
        .per_frame_vsync    (dilation_vsync),
        .per_frame_href     (dilation_href),
        .per_frame_clken    (dilation_clken),
        .per_img_Y          (dilation_img_Bit),

        // 原始 RGB 图像（来自 DVP 控制器）
        .cmos_frame_vsync   (dvp_vsync),
        .cmos_frame_href    (dvp_href),
        .cmos_frame_clken   (dvp_valid),
        .cmos_frame_data    (dvp_data),

        // 输出：带红色矩形标记的图像
        .post_frame_vsync   (post_frame_vsync),
        .post_frame_href    (post_frame_href),
        .post_frame_clken   (post_frame_clken),
        .post_img_Y         (post_img_Y)
    );

endmodule