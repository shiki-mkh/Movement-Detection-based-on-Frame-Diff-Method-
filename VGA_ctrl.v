module vga_display(
    input              vga_clk,       // 25MHz 像素时钟
    input              rst_n,         // 低电平复位

    // SDRAM读FIFO接口
    input      [15:0]  fifo_data,     // SDRAM读出数据（RGB565格式）
    input              fifo_empty,    // FIFO空标志
    output reg         fifo_rdreq,    // FIFO读请求

    // VGA输出信号
    output reg [4:0]   vga_r,         // R分量
    output reg [5:0]   vga_g,         // G分量
    output reg [4:0]   vga_b,         // B分量
    output reg         vga_hs,        // 行同步
    output reg         vga_vs,        // 场同步
    output reg         vga_valid      // 有效显示区域标志
);
    // ========================
    // VGA Timing Generator
    // ========================
    parameter H_VISIBLE = 640;
    parameter H_FRONT   = 16;
    parameter H_SYNC    = 96;
    parameter H_BACK    = 48;
    parameter H_TOTAL   = 800;

    parameter V_VISIBLE = 480;
    parameter V_FRONT   = 10;
    parameter V_SYNC    = 2;
    parameter V_BACK    = 33;
    parameter V_TOTAL   = 525;

    reg [9:0] h_cnt;
    reg [9:0] v_cnt;

    // 水平计数器
    always @(posedge vga_clk or negedge rst_n) begin
        if(!rst_n)
            h_cnt <= 10'd0;
        else if(h_cnt == H_TOTAL - 1)
            h_cnt <= 10'd0;
        else
            h_cnt <= h_cnt + 1'b1;
    end

    // 垂直计数器
    always @(posedge vga_clk or negedge rst_n) begin
        if(!rst_n)
            v_cnt <= 10'd0;
        else if(h_cnt == H_TOTAL - 1) begin
            if(v_cnt == V_TOTAL - 1)
                v_cnt <= 10'd0;
            else
                v_cnt <= v_cnt + 1'b1;
        end
    end

    // 行同步信号
    always @(posedge vga_clk or negedge rst_n)
        if(!rst_n)
            vga_hs <= 1'b1;
        else
            vga_hs <= ~((h_cnt >= H_VISIBLE + H_FRONT) && (h_cnt < H_VISIBLE + H_FRONT + H_SYNC));

    // 场同步信号
    always @(posedge vga_clk or negedge rst_n)
        if(!rst_n)
            vga_vs <= 1'b1;
        else
            vga_vs <= ~((v_cnt >= V_VISIBLE + V_FRONT) && (v_cnt < V_VISIBLE + V_FRONT + V_SYNC));



    // 有效显示区域标志
    always @(posedge vga_clk or negedge rst_n)
        if(!rst_n)
            vga_valid <= 1'b0;
        else
            vga_valid <= (h_cnt < H_VISIBLE && v_cnt < V_VISIBLE);
    reg [15:0] pixel_data;

////////////////////
// 读FIFO控制
////////////////////

    always @(posedge vga_clk or negedge rst_n) begin
        if(!rst_n) begin
            fifo_rdreq <= 1'b0;
            pixel_data <= 16'd0;
        end else if(vga_valid) begin
            if(!fifo_empty) begin
                fifo_rdreq <= 1'b1;
                pixel_data <= fifo_data;
            end else begin
                fifo_rdreq <= 1'b0;
            end
        end else begin
            fifo_rdreq <= 1'b0;
        end
    end

///////////////////
// VGA颜色输出
///////////////////

    always @(posedge vga_clk or negedge rst_n) begin
        if(!rst_n) begin
            vga_r <= 5'd0;
            vga_g <= 6'd0;
            vga_b <= 5'd0;
        end else if(vga_valid) begin
            vga_r <= pixel_data[15:11];
            vga_g <= pixel_data[10:5];
            vga_b <= pixel_data[4:0];
        end else begin
            vga_r <= 5'd0;
            vga_g <= 6'd0;
            vga_b <= 5'd0;
        end
    end
endmodule
