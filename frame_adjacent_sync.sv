// 实现灰度图像的移位，与 SDRAM ctrl 交互，控制读和写
// 调整时序，使两帧图像对齐，打包发出

`timescale 1ns/1ns
module frame_adjacent_sync (
    input         clk,
    input         rst_n,

    input         clken,
    input         gray_vsync, 
    input         gray_href, 

    input  [7:0]  gray_data,  // next
    input  [7:0]  gray_sdr,   // before

    output        sdr_rd,     // 延时一帧的使能信号
    output [15:0] ajct_gray,  // 打包两帧灰度图
    output        ajct_vsync,
    output        ajct_href,
    output        ajct_clken
);

//////////////////////////////////////////////////////
// ---------------- 延时同步信号 ----------------
reg gray_vsync_d0; 
reg gray_href_d0; 
reg clken_d0;
reg [7:0] gray_data_d0;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        gray_vsync_d0 <= 1'b0;
        gray_href_d0  <= 1'b0;
        clken_d0      <= 1'b0;
        gray_data_d0  <= 8'd0;
    end else begin
        gray_vsync_d0 <= gray_vsync;
        gray_href_d0  <= gray_href;
        clken_d0      <= clken;
        gray_data_d0  <= gray_data;
    end
end

// ---------------- SDRAM 读使能 ----------------
reg rd_en; 
always @(posedge clk or negedge rst_n) begin 
    if (!rst_n) 
        rd_en <= 1'b0; 
    else if (~gray_vsync & gray_vsync_d0) // 帧同步下降沿开始读
        rd_en <= 1'b1; 
end 
 
assign sdr_rd = rd_en & clken; 

// ---------------- 输出 ----------------
assign ajct_vsync = gray_vsync_d0;
assign ajct_href  = gray_href_d0;
assign ajct_clken = clken_d0;
assign ajct_gray  = {gray_data_d0, gray_sdr};

endmodule
