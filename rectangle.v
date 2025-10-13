`timescale 1ns/1ns
module rectangle #(
    parameter [10:0] IMG_WIDTH = 11'd640,   // 图像宽度
    parameter [10:0] IMG_HEIGHT = 11'd480   // 图像高度
)(
    input               clk,
    input               rst_n,

    // 二值化图像输入（目标检测）
    input               per_frame_vsync,
    input               per_frame_href,
    input               per_frame_clken,
    input               per_img_Y,

    // 原始 CMOS 图像输入
    input               cmos_frame_vsync,
    input               cmos_frame_href,
    input               cmos_frame_clken,
    input   [15:0]      cmos_frame_data,

    // 带矩形标记的输出
    output              post_frame_vsync,
    output              post_frame_href,
    output              post_frame_clken,
    output  [15:0]      post_img_Y
);

    // ------------------------
    // 信号寄存（同步检测用）
    // ------------------------
    reg per_frame_vsync_r, per_frame_href_r;
    reg per_frame_clken_r, per_img_Y_r;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            per_frame_vsync_r <= 1'b0;
            per_frame_href_r  <= 1'b0;
            per_frame_clken_r <= 1'b0;
            per_img_Y_r       <= 1'b0;
        end else begin
            per_frame_vsync_r <= per_frame_vsync;
            per_frame_href_r  <= per_frame_href;
            per_frame_clken_r <= per_frame_clken;
            per_img_Y_r       <= per_img_Y;
        end
    end

    reg cmos_frame_vsync_r, cmos_frame_href_r, cmos_frame_clken_r;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            cmos_frame_vsync_r <= 1'b0;
            cmos_frame_href_r  <= 1'b0;
            cmos_frame_clken_r <= 1'b0;
        end else begin
            cmos_frame_vsync_r <= cmos_frame_vsync;
            cmos_frame_href_r  <= cmos_frame_href;
            cmos_frame_clken_r <= cmos_frame_clken;
        end
    end

    // ------------------------
    // 行列计数器
    // ------------------------
    reg [9:0] h_cnt, v_cnt;
    wire href_falling  = per_frame_href_r & ~per_frame_href;
    wire vsync_rising  = ~per_frame_vsync_r & per_frame_vsync;
    wire vsync_falling =  per_frame_vsync_r & ~per_frame_vsync;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            h_cnt <= 10'd0;
        else if(per_frame_href) begin
            if(per_frame_clken) 
                h_cnt <= h_cnt + 1'b1;
        end 
        else
            h_cnt <= 10'd0;
    end

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)
            v_cnt <= 10'd0;
        else if(per_frame_vsync) begin
            if(href_falling) v_cnt <= v_cnt + 1'b1;
        end 
        else
            v_cnt <= 10'd0;
    end

    // ------------------------
    // 边界检测
    // ------------------------
    reg [9:0] edg_up, edg_down, edg_left, edg_right;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n || vsync_rising) begin
            edg_up    <= IMG_HEIGHT-1;
            edg_down  <= 10'd0;
            edg_left  <= IMG_WIDTH-1;
            edg_right <= 10'd0;
        end else if(per_frame_clken && per_frame_href && per_img_Y) begin
            if(v_cnt < edg_up)     edg_up    <= v_cnt;
            if(v_cnt > edg_down)   edg_down  <= v_cnt;
            if(h_cnt < edg_left)   edg_left  <= h_cnt;
            if(h_cnt > edg_right)  edg_right <= h_cnt;
        end
    end

    // ------------------------
    // 锁存边界（帧结束）
    // ------------------------
    reg [9:0] edg_up_d1, edg_down_d1, edg_left_d1, edg_right_d1;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            edg_up_d1    <= 10'd160;
            edg_down_d1  <= 10'd240;
            edg_left_d1  <= 10'd160;
            edg_right_d1 <= 10'd240;
        end else if(vsync_falling) begin
            edg_up_d1    <= edg_up;
            edg_down_d1  <= edg_down;
            edg_left_d1  <= edg_left;
            edg_right_d1 <= edg_right;
        end
    end

    // ------------------------
    // 矩形绘制逻辑
    // ------------------------
    reg [15:0] post_cmos_data;
    wire valid_en = 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) 
            post_cmos_data <= 16'd0;
        else if(cmos_frame_vsync) begin
            if(~(cmos_frame_href & cmos_frame_clken))
                post_cmos_data <= 16'd0;
            else if(valid_en && (
                // 左右边框（宽度=4）
                ((((h_cnt >= edg_left_d1)  && (h_cnt <= edg_left_d1+3)) ||
                  ((h_cnt >= edg_right_d1) && (h_cnt <= edg_right_d1+3)))
                  && (v_cnt >= edg_up_d1 && v_cnt <= edg_down_d1))
                ||
                // 上下边框（高度=4）
                ((((v_cnt >= edg_up_d1)    && (v_cnt <= edg_up_d1+3)) ||
                  ((v_cnt >= edg_down_d1) && (v_cnt <= edg_down_d1+3)))
                  && (h_cnt >= edg_left_d1 && h_cnt <= edg_right_d1))
            ))
                post_cmos_data <= {5'b11111,6'd0,5'd0};  // 红色边框
            else
                post_cmos_data <= cmos_frame_data;        // 原图透传
        end
    end

    // ------------------------
    // 输出
    // ------------------------
    assign post_frame_vsync  = cmos_frame_vsync_r;
    assign post_frame_href   = cmos_frame_href_r;
    assign post_frame_clken  = cmos_frame_clken_r;
    assign post_img_Y        = post_cmos_data;

endmodule
