`timescale 1ns / 1ps
module Binarization #(
    parameter THRESHOLD = 8'd30   // 二值化阈值，可调
)(
    input  wire        clk,          
    input  wire        rst_n,        

    input  wire        ajct_clken,   
    input  wire        ajct_href,    
    input  wire        ajct_vsync,   
    input  wire [15:0] ajct_gray,    

    output reg         binarize_clken, 
    output reg         binarize_href,  
    output reg         binarize_vsync, 
    output reg         binarize_img_Bit 
);

    // ---------------- 拆分两帧灰度值 ----------------
    wire [7:0] curr_gray = ajct_gray[15:8];
    wire [7:0] prev_gray = ajct_gray[7:0];

    // ---------------- 计算差值 (绝对值) ----------------
    wire [8:0] diff_raw = (curr_gray > prev_gray) ?
                          (curr_gray - prev_gray) :
                          (prev_gray - curr_gray);

    // ---------------- 二值化 ----------------
    wire bin_result = (diff_raw > THRESHOLD) ? 1'b1 : 1'b0;

    // ---------------- 打拍输出，时序对齐 ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            binarize_img_Bit <= 1'b0;
            binarize_clken   <= 1'b0;
            binarize_href    <= 1'b0;
            binarize_vsync   <= 1'b0;
        end else begin
            binarize_img_Bit <= bin_result;
            binarize_clken   <= ajct_clken;
            binarize_href    <= ajct_href;
            binarize_vsync   <= ajct_vsync;
        end
    end

endmodule
