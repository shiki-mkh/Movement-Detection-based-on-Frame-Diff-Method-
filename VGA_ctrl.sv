`timescale 1ns / 1ps
module VGA_ctrl #(
    parameter H_DISP = 640,  // 水平分辨率
    parameter V_DISP = 480   // 垂直分辨率
)(
    input              vga_clk,    // VGA 时钟（25MHz）
    input              rst_n,      // 复位信号（低有效）

    // SDRAM/FIFO 接口
    input      [15:0]  fifo_data,  // SDRAM 输出的数据（RGB565）
    input              fifo_empty, // FIFO 空标志
    output reg         fifo_rdreq, // FIFO 读请求信号

    // VGA 输出信号
    output reg [4:0]   vga_r,
    output reg [5:0]   vga_g,
    output reg [4:0]   vga_b,
    output reg         vga_hs,
    output reg         vga_vs,
    output             vga_valid   // VGA 有效显示区信号
);

    // VGA Timing Parameters (640x480@60Hz)
    parameter H_SYNC  = 96;
    parameter H_BACK  = 48;
    parameter H_FRONT = 16;
    parameter H_TOTAL = H_SYNC + H_BACK + H_DISP + H_FRONT;

    parameter V_SYNC  = 2;
    parameter V_BACK  = 33;
    parameter V_FRONT = 10;
    parameter V_TOTAL = V_SYNC + V_BACK + V_DISP + V_FRONT;

    reg [10:0] h_cnt;
    reg [9:0]  v_cnt;

    //--------------------------------------------
    // 行扫描计数器
    //--------------------------------------------
    always @(posedge vga_clk or negedge rst_n) begin
        if(!rst_n)
            h_cnt <= 0;
        else if(h_cnt == H_TOTAL - 1)
            h_cnt <= 0;
        else
            h_cnt <= h_cnt + 1;
    end

    //--------------------------------------------
    // 场扫描计数器
    //--------------------------------------------
    always @(posedge vga_clk or negedge rst_n) begin
        if(!rst_n)
            v_cnt <= 0;
        else if(h_cnt == H_TOTAL - 1) begin
            if(v_cnt == V_TOTAL - 1)
                v_cnt <= 0;
            else
                v_cnt <= v_cnt + 1;
        end
    end

    //--------------------------------------------
    // 生成同步信号
    //--------------------------------------------
    always @(posedge vga_clk or negedge rst_n) begin
        if(!rst_n) begin
            vga_hs <= 1'b1;
            vga_vs <= 1'b1;
        end else begin
            vga_hs <= (h_cnt < H_SYNC) ? 1'b0 : 1'b1;
            vga_vs <= (v_cnt < V_SYNC) ? 1'b0 : 1'b1;
        end
    end

    //--------------------------------------------
    // 有效显示区判定
    //--------------------------------------------
    wire h_active = (h_cnt >= (H_SYNC + H_BACK)) && (h_cnt < (H_SYNC + H_BACK + H_DISP));
    wire v_active = (v_cnt >= (V_SYNC + V_BACK)) && (v_cnt < (V_SYNC + V_BACK + V_DISP));
    assign vga_valid = h_active && v_active;

    //--------------------------------------------
    // FIFO 读控制逻辑
    //--------------------------------------------
    reg [15:0] pixel_data;

    always @(posedge vga_clk or negedge rst_n) begin
        if(!rst_n)
            fifo_rdreq <= 1'b0;
        else if(vga_valid && !fifo_empty)
            fifo_rdreq <= 1'b1;   // 有效区域持续读取
        else
            fifo_rdreq <= 1'b0;
    end

    //--------------------------------------------
    // 像素数据采样与输出
    //--------------------------------------------
    always @(posedge vga_clk or negedge rst_n) begin
        if(!rst_n)
            pixel_data <= 16'd0;
        else if(fifo_rdreq)
            pixel_data <= fifo_data;  // 从 SDRAM 取出的像素
    end

    always @(posedge vga_clk or negedge rst_n) begin
        if(!rst_n) begin
            vga_r <= 0;
            vga_g <= 0;
            vga_b <= 0;
        end else if(vga_valid) begin
            vga_r <= pixel_data[15:11];
            vga_g <= pixel_data[10:5];
            vga_b <= pixel_data[4:0];
        end else begin
            vga_r <= 0;
            vga_g <= 0;
            vga_b <= 0;
        end
    end

endmodule
