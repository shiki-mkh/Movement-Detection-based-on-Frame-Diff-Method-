module rgb2gray (
    input  wire        clk,
    input  wire        rst_n,
    
    input              dvp_vsync,  //帧有效信号    
    input              dvp_href ,  //行有效信号
    input              dvp_valid,  //数据有效使能信号
    input       [15:0] dvp_data,   //RGB565 输入数据

    output reg         gray_valid,
    output reg         gray_vsync,
    output reg         gray_href,
    output reg  [7:0]  gray_data
);

    // ================= Stage1: RGB 提取与扩展 =================
    wire [4:0] R5 = dvp_data[15:11];
    wire [5:0] G6 = dvp_data[10:5];
    wire [4:0] B5 = dvp_data[4:0];

    wire [7:0] R8 = {R5, R5[4:2]};
    wire [7:0] G8 = {G6, G6[5:4]};
    wire [7:0] B8 = {B5, B5[4:2]};

    reg [7:0] R8_r, G8_r, B8_r;
    reg       vld_s1, vsync_s1, href_s1;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            R8_r <= 0; G8_r <= 0; B8_r <= 0;
            vld_s1 <= 0; vsync_s1 <= 0; href_s1 <= 0;
        end else begin
            R8_r <= R8;
            G8_r <= G8;
            B8_r <= B8;
            vld_s1   <= dvp_valid;
            vsync_s1 <= dvp_vsync;
            href_s1  <= dvp_href;
        end
    end

    // ================= Stage2: 加权乘法（移位加法） =================
    wire [15:0] multR = (R8_r << 6) + (R8_r << 3) + (R8_r << 2) + R8_r;   //约 0.299
    wire [16:0] multG = (G8_r << 7) + (G8_r << 4) + (G8_r << 2) + (G8_r << 1); //约 0.587
    wire [15:0] multB = (B8_r << 4) + (B8_r << 3) + (B8_r << 2) + B8_r;   //约 0.114

    reg [16:0] Rw_r, Gw_r, Bw_r;
    reg        vld_s2, vsync_s2, href_s2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            Rw_r <= 0; Gw_r <= 0; Bw_r <= 0;
            vld_s2 <= 0; vsync_s2 <= 0; href_s2 <= 0;
        end else begin
            Rw_r <= multR;
            Gw_r <= multG;
            Bw_r <= multB;
            vld_s2   <= vld_s1;
            vsync_s2 <= vsync_s1;
            href_s2  <= href_s1;
        end
    end

    // ================= Stage3: 求和 + >>8 =================
    wire [17:0] sum  = Rw_r + Gw_r + Bw_r;
    wire [7:0]  gray = sum[15:8];   //取高 8 位作为灰度值

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gray_data  <= 0;
            gray_valid <= 0;
            gray_vsync <= 0;
            gray_href  <= 0;
        end else begin
            gray_data  <= gray;
            gray_valid <= vld_s2;
            gray_vsync <= vsync_s2;
            gray_href  <= href_s2;
        end
    end

endmodule
