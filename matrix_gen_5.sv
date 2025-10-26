`timescale 1ns/1ns
module matrix_gen_5
#(
    parameter [9:0] IMG_HDISP = 10'd640    // 图像水平分辨率
)
(
    input               clk,
    input               rst_n,

    // 输入二值化信号
    input               per_frame_vsync,
    input               per_frame_href,
    input               per_frame_clken,
    input               per_img_Bit,

    // 输出矩阵
    output reg          matrix_frame_vsync,
    output reg          matrix_frame_href,
    output reg          matrix_frame_clken,
    output reg [4:0]    matrix [4:0]       // 5x5 矩阵，每行5bit
);

// Generate 5*5 matrix 
//--------------------------------------------------------------------------
// sync row5_data with per_frame_clken & row1_data & row2_data & row3_data & row4_data
wire    row1_data;  // frame data of the 1th row (oldest)
wire    row2_data;  // frame data of the 2th row
wire    row3_data;  // frame data of the 3th row  
wire    row4_data;  // frame data of the 4th row
reg     row5_data;  // frame data of the 5th row (newest)

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        row5_data <= 0;
    else 
    begin
        if(per_frame_clken)
            row5_data <= per_img_Bit;
        else
            row5_data <= row5_data;
    end    
end

//---------------------------------------
// module of shift ram for raw data using new IP
wire    shift_clk_en = per_frame_clken;

// 实例化 Shift Register IP
shift_ram_5tap u_Line_Shift_RAM_5Row (
    .clock      (clk),
    .clken      (shift_clk_en),     // pixel enable clock
    .shiftin    (row5_data),        // Current data input (newest row)
    .shiftout   (),                 // Not used in this case
    .taps       ({row4_data, row3_data, row2_data, row1_data}) // 4 tap outputs
);

//------------------------------------------
// lag 4 clocks signal sync (因为5x5矩阵需要4行延迟)
reg [3:0]   per_frame_vsync_r;
reg [3:0]   per_frame_href_r;   
reg [3:0]   per_frame_clken_r;

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        per_frame_vsync_r <= 0;
        per_frame_href_r <= 0;
        per_frame_clken_r <= 0;
    end
    else
    begin
        per_frame_vsync_r  <=  {per_frame_vsync_r[2:0],  per_frame_vsync};
        per_frame_href_r   <=  {per_frame_href_r[2:0],   per_frame_href};
        per_frame_clken_r  <=  {per_frame_clken_r[2:0],  per_frame_clken};
    end
end

// Give up the 1th-4th row edge data caculate for simple process
// Give up the 1th-4th point of 1 line for simple process
wire    read_frame_href     =   per_frame_href_r[0];    // RAM read href sync signal
wire    read_frame_clken    =   per_frame_clken_r[0];   // RAM read enable

// 输出同步信号
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        matrix_frame_vsync <= 0;
        matrix_frame_href  <= 0;
        matrix_frame_clken <= 0;
    end
    else
    begin
        matrix_frame_vsync <= per_frame_vsync_r[3];
        matrix_frame_href  <= per_frame_href_r[3];
        matrix_frame_clken <= per_frame_clken_r[3];
    end
end

//----------------------------------------------------------------------------
/******************************************************************************
                    ----------    Convert Matrix    ----------
                [ P51 -> P52 -> P53 -> P54 -> P55 ]  --->  matrix[4] = {P51,P52,P53,P54,P55}
                [ P41 -> P42 -> P43 -> P44 -> P45 ]  --->  matrix[3] = {P41,P42,P43,P44,P45}
                [ P31 -> P32 -> P33 -> P34 -> P35 ]  --->  matrix[2] = {P31,P32,P33,P34,P35}
                [ P21 -> P22 -> P23 -> P24 -> P25 ]  --->  matrix[1] = {P21,P22,P23,P24,P25}
                [ P11 -> P12 -> P13 -> P14 -> P15 ]  --->  matrix[0] = {P11,P12,P13,P14,P15}
******************************************************************************/
// 内部寄存器用于构建5x5矩阵
reg [4:0] matrix_r [4:0];  // 内部矩阵寄存器

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        // 初始化所有矩阵行为0
        matrix_r[0] <= 5'b0;
        matrix_r[1] <= 5'b0;
        matrix_r[2] <= 5'b0;
        matrix_r[3] <= 5'b0;
        matrix_r[4] <= 5'b0;
        
        // 初始化输出矩阵
        matrix[0] <= 5'b0;
        matrix[1] <= 5'b0;
        matrix[2] <= 5'b0;
        matrix[3] <= 5'b0;
        matrix[4] <= 5'b0;
    end
    else if(read_frame_href)
    begin
        if(read_frame_clken)    // Shift_RAM data read clock enable
        begin
            // Row 0 (oldest) - shift input from tap output
            matrix_r[0] <= {matrix_r[0][3:0], row1_data};
            
            // Row 1
            matrix_r[1] <= {matrix_r[1][3:0], row2_data};
                
            // Row 2  
            matrix_r[2] <= {matrix_r[2][3:0], row3_data};
                
            // Row 3
            matrix_r[3] <= {matrix_r[3][3:0], row4_data};
                
            // Row 4 (newest) - shift input from current pixel
            matrix_r[4] <= {matrix_r[4][3:0], row5_data};
            
            // 将内部寄存器值赋给输出
            matrix[0] <= matrix_r[0];
            matrix[1] <= matrix_r[1];
            matrix[2] <= matrix_r[2];
            matrix[3] <= matrix_r[3];
            matrix[4] <= matrix_r[4];
        end
        else
        begin
            // 保持当前矩阵值不变
            matrix[0] <= matrix[0];
            matrix[1] <= matrix[1];
            matrix[2] <= matrix[2];
            matrix[3] <= matrix[3];
            matrix[4] <= matrix[4];
        end    
    end
    else
    begin
        // 当href为低时，清除矩阵
        matrix[0] <= 5'b0;
        matrix[1] <= 5'b0;
        matrix[2] <= 5'b0;
        matrix[3] <= 5'b0;
        matrix[4] <= 5'b0;
    end
end

endmodule