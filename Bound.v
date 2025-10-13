`timescale 1ns / 1ps
module DrawBoundingBox #(
    parameter IMG_WIDTH  = 640,
    parameter IMG_HEIGHT = 480
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        morph_valid,   // 输入像素有效
    input  wire        morph_pixel,   // 输入二值化/形态学像素
    input  wire        href_o,        // 行同步
    input  wire        vsync_o,       // 帧同步
    output  reg  [9:0]  x_min_out,
    output  reg  [9:0]  x_max_out,
    output  reg  [9:0]  y_min_out,
    output  reg  [9:0]  y_max_out
);

    // --------------------------
    // 行列计数器
    // --------------------------
    reg [9:0] x_cnt;
    reg [9:0] y_cnt;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            x_cnt <= 0;
            y_cnt <= 0;
        end else if(vsync_o) begin
            x_cnt <= 0;
            y_cnt <= 0;
        end else if(href_o && morph_valid) begin
            if(x_cnt == IMG_WIDTH-1) begin
                x_cnt <= 0;
                if(y_cnt == IMG_HEIGHT-1) y_cnt <= 0;
                else y_cnt <= y_cnt + 1;
            end else begin
                x_cnt <= x_cnt + 1;
            end
        end
    end

    // --------------------------
    // 本帧外接矩形寄存器（累积目标像素）
    // --------------------------
    reg [9:0] x_min, x_max, y_min, y_max;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            x_min <= IMG_WIDTH;
            x_max <= 0;
            y_min <= IMG_HEIGHT;
            y_max <= 0;
        end else if(vsync_o) begin
            // 帧开始清空
            x_min <= IMG_WIDTH;
            x_max <= 0;
            y_min <= IMG_HEIGHT;
            y_max <= 0;
        end else if(morph_valid && morph_pixel) begin
            // 累积本帧外接矩形
            if(x_cnt < x_min) x_min <= x_cnt;
            if(x_cnt > x_max) x_max <= x_cnt;
            if(y_cnt < y_min) y_min <= y_cnt;
            if(y_cnt > y_max) y_max <= y_cnt;
        end
    end

    // --------------------------
    // 输出上一帧矩形寄存器
    // --------------------------
    

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            x_min_out <= 0;
            x_max_out <= 0;
            y_min_out <= 0;
            y_max_out <= 0;
        end else if(vsync_o) begin
            // 将上一帧矩形输出
            x_min_out <= x_min;
            x_max_out <= x_max;
            y_min_out <= y_min;
            y_max_out <= y_max;
        end
    end


endmodule
