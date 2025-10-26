`timescale 1ns/1ns
module matrix_gen_7
#(
    parameter [9:0] IMG_HDISP = 10'd640
)
(
    input               clk,
    input               rst_n,

    input               per_frame_vsync,
    input               per_frame_href,
    input               per_frame_clken,
    input               per_img_Bit,

    output reg          matrix_frame_vsync,
    output reg          matrix_frame_href,
    output reg          matrix_frame_clken,
    output reg [6:0]    matrix [6:0]   // 7x7矩阵，每行7bit
);

// Generate 7*7 matrix 
//--------------------------------------------------------------------------
// sync row7_data with per_frame_clken & row1_data to row6_data
wire    row1_data;  // frame data of the 1th row (oldest)
wire    row2_data;  // frame data of the 2th row
wire    row3_data;  // frame data of the 3th row  
wire    row4_data;  // frame data of the 4th row
wire    row5_data;  // frame data of the 5th row
wire    row6_data;  // frame data of the 6th row
reg     row7_data;  // frame data of the 7th row (newest)

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        row7_data <= 0;
    else 
    begin
        if(per_frame_clken)
            row7_data <= per_img_Bit;
        else
            row7_data <= row7_data;
    end    
end

//---------------------------------------
// module of shift ram for raw data using new IP
wire    shift_clk_en = per_frame_clken;

// 实例化 Shift Register IP (需要6个抽头)
shift_ram_7tap u_Line_Shift_RAM_7Row (
    .clock      (clk),
    .clken      (shift_clk_en),     // pixel enable clock
    .shiftin    (row7_data),        // Current data input (newest row)
    .shiftout   (),                 // Not used in this case
    .taps       ({row6_data, row5_data, row4_data, row3_data, row2_data, row1_data}) // 6 tap outputs
);

//------------------------------------------
// lag 6 clocks signal sync (因为7x7矩阵需要6行延迟)
reg [5:0]   per_frame_vsync_r;
reg [5:0]   per_frame_href_r;   
reg [5:0]   per_frame_clken_r;

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
        per_frame_vsync_r  <=  {per_frame_vsync_r[4:0],  per_frame_vsync};
        per_frame_href_r   <=  {per_frame_href_r[4:0],   per_frame_href};
        per_frame_clken_r  <=  {per_frame_clken_r[4:0],  per_frame_clken};
    end
end

// Give up the 1th-6th row edge data caculate for simple process
// Give up the 1th-6th point of 1 line for simple process
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
        matrix_frame_vsync <= per_frame_vsync_r[5];
        matrix_frame_href  <= per_frame_href_r[5];
        matrix_frame_clken <= per_frame_clken_r[5];
    end
end

//----------------------------------------------------------------------------
/******************************************************************************
                    ----------    Convert Matrix    ----------
                [ P71 -> P72 -> P73 -> P74 -> P75 -> P76 -> P77 ]  --->  matrix[6]
                [ P61 -> P62 -> P63 -> P64 -> P65 -> P66 -> P67 ]  --->  matrix[5]
                [ P51 -> P52 -> P53 -> P54 -> P55 -> P56 -> P57 ]  --->  matrix[4]
                [ P41 -> P42 -> P43 -> P44 -> P45 -> P46 -> P47 ]  --->  matrix[3]
                [ P31 -> P32 -> P33 -> P34 -> P35 -> P36 -> P37 ]  --->  matrix[2]
                [ P21 -> P22 -> P23 -> P24 -> P25 -> P26 -> P27 ]  --->  matrix[1]
                [ P11 -> P12 -> P13 -> P14 -> P15 -> P16 -> P17 ]  --->  matrix[0]
******************************************************************************/
// 内部寄存器用于构建7x7矩阵
reg [6:0] matrix_r [6:0];  // 内部矩阵寄存器

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        // 初始化所有矩阵行为0
        matrix_r[0] <= 7'b0;
        matrix_r[1] <= 7'b0;
        matrix_r[2] <= 7'b0;
        matrix_r[3] <= 7'b0;
        matrix_r[4] <= 7'b0;
        matrix_r[5] <= 7'b0;
        matrix_r[6] <= 7'b0;
        
        // 初始化输出矩阵
        matrix[0] <= 7'b0;
        matrix[1] <= 7'b0;
        matrix[2] <= 7'b0;
        matrix[3] <= 7'b0;
        matrix[4] <= 7'b0;
        matrix[5] <= 7'b0;
        matrix[6] <= 7'b0;
    end
    else if(read_frame_href)
    begin
        if(read_frame_clken)    // Shift_RAM data read clock enable
        begin
            // Row 0 (oldest) - shift input from tap output
            matrix_r[0] <= {matrix_r[0][5:0], row1_data};
            
            // Row 1
            matrix_r[1] <= {matrix_r[1][5:0], row2_data};
                
            // Row 2  
            matrix_r[2] <= {matrix_r[2][5:0], row3_data};
                
            // Row 3
            matrix_r[3] <= {matrix_r[3][5:0], row4_data};
            
            // Row 4
            matrix_r[4] <= {matrix_r[4][5:0], row5_data};
            
            // Row 5
            matrix_r[5] <= {matrix_r[5][5:0], row6_data};
                
            // Row 6 (newest) - shift input from current pixel
            matrix_r[6] <= {matrix_r[6][5:0], row7_data};
            
            // 将内部寄存器值赋给输出
            matrix[0] <= matrix_r[0];
            matrix[1] <= matrix_r[1];
            matrix[2] <= matrix_r[2];
            matrix[3] <= matrix_r[3];
            matrix[4] <= matrix_r[4];
            matrix[5] <= matrix_r[5];
            matrix[6] <= matrix_r[6];
        end
        else
        begin
            // 保持当前矩阵值不变
            matrix[0] <= matrix[0];
            matrix[1] <= matrix[1];
            matrix[2] <= matrix[2];
            matrix[3] <= matrix[3];
            matrix[4] <= matrix[4];
            matrix[5] <= matrix[5];
            matrix[6] <= matrix[6];
        end    
    end
    else
    begin
        // 当href为低时，清除矩阵
        matrix[0] <= 7'b0;
        matrix[1] <= 7'b0;
        matrix[2] <= 7'b0;
        matrix[3] <= 7'b0;
        matrix[4] <= 7'b0;
        matrix[5] <= 7'b0;
        matrix[6] <= 7'b0;
    end
end

endmodule