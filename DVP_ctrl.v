module cmos_capture_data(
    input                 rst_n        ,  //复位信号
    //摄像头接口
    input                 ov5640_pclk  ,  //cmos 数据像素时钟
    input                 ov5640_vsync ,  //cmos 场同步信号
    input                 ov5640_href  ,  //cmos 行同步信号
    input        [7:0]    ov5640_data  ,  //cmos 数据                             
    //用户接口
    output                dvp_vsync,  //帧有效信号    
    output                dvp_href ,  //行有效信号
    output                dvp_valid,  //数据有效使能信号
    output       [15:0]   dvp_data   //有效数据        
);

//寄存器全部配置完成后，先等待10帧数据
//待寄存器配置生效后再开始采集图像
parameter  STABLE_FRAME = 4'd10;   //寄存器数据稳定等待的帧个数            

//reg define
reg             ov5640_vsync_d0;
reg             ov5640_vsync_d1;
reg             ov5640_href_d0;
reg             ov5640_href_d1;
reg    [3:0]    wait_ps_cnt;       //等待帧数稳定计数器
reg             frame_valid;       //帧有效的标志

reg    [7:0]    ov5640_data_d0;             
reg    [15:0]   dvp_data_t;        //用于8位转16位的临时寄存器
reg             byte_flag;             
reg             byte_flag_d0;

//wire define
wire            pos_vsync;

//*****************************************************
//**                    main code
//*****************************************************

//采输入场同步信号的上升沿
assign pos_vsync = (~ov5640_vsync_d1) & ov5640_vsync_d0;  

//输出帧有效信号
assign  dvp_vsync = frame_valid ? ov5640_vsync_d1 : 1'b0; 
//输出行有效信号
assign  dvp_href  = frame_valid ? ov5640_href_d1  : 1'b0; 
//输出数据使能有效信号
assign  dvp_valid = frame_valid ? byte_flag_d0    : 1'b0; 
//输出数据
assign  dvp_data  = frame_valid ? dvp_data_t      : 16'd0; 

//对输入的 vsync/href 打拍
always @(posedge ov5640_pclk or negedge rst_n) begin
    if(!rst_n) begin
        ov5640_vsync_d0 <= 1'b0;
        ov5640_vsync_d1 <= 1'b0;
        ov5640_href_d0  <= 1'b0;
        ov5640_href_d1  <= 1'b0;
    end
    else begin
        ov5640_vsync_d0 <= ov5640_vsync;
        ov5640_vsync_d1 <= ov5640_vsync_d0;
        ov5640_href_d0  <= ov5640_href;
        ov5640_href_d1  <= ov5640_href_d0;
    end
end

//对帧数进行计数
always @(posedge ov5640_pclk or negedge rst_n) begin
    if(!rst_n)
        wait_ps_cnt <= 4'd0;
    else if(pos_vsync && (wait_ps_cnt < STABLE_FRAME))
        wait_ps_cnt <= wait_ps_cnt + 4'd1;
end

//帧有效标志
always @(posedge ov5640_pclk or negedge rst_n) begin
    if(!rst_n)
        frame_valid <= 1'b0;
    else if((wait_ps_cnt == STABLE_FRAME) && pos_vsync)
        frame_valid <= 1'b1;
end            

//8位数据转16位 RGB565 数据        
always @(posedge ov5640_pclk or negedge rst_n) begin
    if(!rst_n) begin
        dvp_data_t     <= 16'd0;
        ov5640_data_d0 <= 8'd0;
        byte_flag      <= 1'b0;
    end
    else if(ov5640_href) begin
        byte_flag      <= ~byte_flag;
        ov5640_data_d0 <= ov5640_data;
        if(byte_flag)
            dvp_data_t <= {ov5640_data_d0, ov5640_data};
    end
    else begin
        byte_flag      <= 1'b0;
        ov5640_data_d0 <= 8'b0;
    end    
end        

//产生输出数据有效信号(dvp_valid)
always @(posedge ov5640_pclk or negedge rst_n) begin
    if(!rst_n)
        byte_flag_d0 <= 1'b0;
    else
        byte_flag_d0 <= byte_flag;    
end          

endmodule
