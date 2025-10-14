`timescale 1ns / 1ns
module Project_TOP (
    input         clk,            // 50MHz system clock
    input         rst_n,          // global reset

    // SDRAM interface
    output        sdram_clk,
    output        sdram_cke,
    output        sdram_cs_n,
    output        sdram_we_n,
    output        sdram_cas_n,
    output        sdram_ras_n,
    output [1:0]  sdram_dqm,
    output [1:0]  sdram_ba,
    output [12:0] sdram_addr,
    inout  [15:0] sdram_data,

    // CMOS interface
    input         cam_pclk,
    input         cam_vsync,
    input         cam_href,
    input  [7:0]  cam_data,
    output        cam_rst_n,
    output        cam_pwdn,
    output        cam_scl,
    inout         cam_sda,

    // VGA output
    output [4:0]  vga_r,
    output [5:0]  vga_g,
    output [4:0]  vga_b,
    output        vga_hs,
    output        vga_vs
);

    //---------------------------------------------
    // system clock and reset
    //---------------------------------------------
    wire pll_rst_n;
    wire sys_rst_n;
    wire clk_ref;
    wire clk_refout;
    wire clk_vga;
    wire clk_48M;
    wire cam_xclk;

    system_ctrl_pll u_system_ctrl_pll (
        .clk       (clk),
        .rst_n     (rst_n),
        .sys_rst_n (pll_rst_n),
        .clk_c0    (clk_ref),      // 100MHz
        .clk_c1    (clk_refout),   // 100MHz -90deg
        .clk_c2    (clk_vga),      // 25MHz VGA clock
        .clk_c3    (cam_xclk),     // 24MHz CMOS clock
        .clk_c4    (clk_48M)
    );

    assign sys_rst_n = pll_rst_n;

    //---------------------------------------------
    // Camera I2C configuration
    //---------------------------------------------
    parameter SLAVE_ADDR   = 7'h3c;
    parameter BIT_CTRL     = 1'b1;
    parameter CLK_FREQ     = 26'd25_000_000;
    parameter I2C_FREQ     = 18'd250_000;
    parameter CMOS_H_PIXEL = 24'd640;
    parameter CMOS_V_PIXEL = 24'd480;

    wire i2c_exec, i2c_done, i2c_dri_clk;
    wire [23:0] i2c_data;
    wire cam_init_done;

    assign cam_rst_n = 1'b1;
    assign cam_pwdn  = 1'b0;

    i2c_ov5640_rgb565_cfg #(
        .CMOS_H_PIXEL(CMOS_H_PIXEL),
        .CMOS_V_PIXEL(CMOS_V_PIXEL)
    ) u_i2c_cfg (
        .clk       (i2c_dri_clk),
        .rst_n     (rst_n),
        .i2c_done  (i2c_done),
        .i2c_exec  (i2c_exec),
        .i2c_data  (i2c_data),
        .init_done (cam_init_done)
    );

    i2c_dri #(
        .SLAVE_ADDR(SLAVE_ADDR),
        .CLK_FREQ  (CLK_FREQ),
        .I2C_FREQ  (I2C_FREQ)
    ) u_i2c_dri (
        .clk         (clk_vga),
        .rst_n       (rst_n),
        .i2c_exec    (i2c_exec),
        .bit_ctrl    (BIT_CTRL),
        .i2c_rh_wl   (1'b0),
        .i2c_addr    (i2c_data[23:8]),
        .i2c_data_w  (i2c_data[7:0]),
        .i2c_data_r  (),
        .i2c_done    (i2c_done),
        .scl         (cam_scl),
        .sda         (cam_sda),
        .dri_clk     (i2c_dri_clk)
    );

    //---------------------------------------------
    // Image Processing (includes DVP)
    //---------------------------------------------
	wire			cmos_frame_vsync;	//cmos frame data vsync valid signal
	wire			cmos_frame_href;	//cmos frame data href vaild  signal
	wire	[15:0]	cmos_frame_data;	//cmos frame data output: {cmos_data[7:0]<<8, cmos_data[7:0]}	
	wire			cmos_frame_clken;	

	DVP_ctrl u_DVP_ctrl(
    .rst_n               (rst_n & cam_init_done), //系统初始化完成之后再开始采集数据 
    .cam_pclk            (cam_pclk),
    .cam_vsync           (!cam_vsync),
    .cam_href            (cam_href),
    .cam_data            (cam_data),         
    .cmos_frame_vsync    (cmos_frame_vsync),
    .cmos_frame_href     (cmos_frame_href),
    .cmos_frame_valid    (cmos_frame_clken),            //数据有效使能信号
    .cmos_frame_data     (cmos_frame_data)           //有效数据 
    );

	//********************************************
	wire [15:0]  gray_sft; 
	wire         sdr_rd; 
	wire         gs_clken ;
	wire         post_frame_vsync;
	wire         post_frame_href;
	wire [15:0]  post_img_data;
	wire         post_frame_clken;




    //---------------------------------------------
    // SDRAM: Dual Write + Dual Read
    //---------------------------------------------
    // Write port1: 灰度图缓存 (这里可以预留给帧差缓存)
    wire [7:0] sdr_wr1_wrdata = gray_sft[15:8];
    wire sdr_wr1_wrreq = gs_clken ;   
    wire sdr_wr1_clk   = cam_pclk;

    // Read port1: 灰度帧读取 (预留)
    wire [7:0] sys_data_out1;
    wire sdr_rd1_clk = cam_pclk;
    wire sys_rd1 = sdr_rd;
    wire RD1_EMPTY;

    // Write port2: 带矩形标记的图像（来自 IMGD_TOP）
    wire [15:0] sdr_wr2_wrdata = post_img_data;
    wire sdr_wr2_wrreq = post_frame_clken;
    wire sdr_wr2_clk = cam_pclk;

    // Read port2: VGA 读取
    wire [15:0] sys_data_out2;
    wire sdr_rd2_clk = clk_vga;
    wire sys_rd2;
    wire RD2_EMPTY;
    wire sdram_init_done;

	IMGD_TOP
	#(
		.IMG_HDISP(10'd640),	//640*480
		.IMG_VDISP(10'd480)
	)
	u_IMGD_TOP
	(
		//global clock
		.clk				   	(cam_pclk),  			//cmos video pixel clock
		.rst_n					(sys_rst_n),			//global reset
		.dvp_valid		(cmos_frame_clken), 	//Prepared Image data vsync valid signal
		.dvp_vsync		(cmos_frame_vsync), 		//Prepared Image data href vaild  signal
		.dvp_href		(cmos_frame_href ), 	//Prepared Image data output/capture enable clock
		.dvp_data        (cmos_frame_data),			//Prepared Image brightness input
		//Image data has been processd
		.post_frame_vsync    (post_frame_vsync),
		.post_frame_href		(post_frame_href),		//Processed Image data href vaild  signal
		.post_frame_clken		(post_frame_clken),		//Processed Image data output/capture enable clock
		.post_img_Y       (post_img_data),			//Processed Image brightness output


		///TODO: IMGD 需要添加的信号
		.sys_data_out1       (sys_data_out1),
		.gs_clken            (gs_clken),
		.gray_sft            (gray_sft),
		.sdr_rd              (sdr_rd),
		//user interface

	);

    SDRAM_ctrl_TOP u_SDRAM_ctrl_TOP (
        // HOST Side
        .REF_CLK(clk_ref),
        .OUT_CLK(clk_refout),
        .RESET_N(sys_rst_n),

        // Write port1
        .WR1_DATA(sdr_wr1_wrdata),
        .WR1(sdr_wr1_wrreq),
        .WR1_ADDR(0),
        .WR1_MAX_ADDR(640*480),
        .WR1_LENGTH(256),
        .WR1_LOAD(~sys_rst_n),
        .WR1_CLK(sdr_wr1_clk),
        .WR1_FULL(),
        .WR1_USE(),

        // Write port2
        .WR2_DATA(sdr_wr2_wrdata),
        .WR2(sdr_wr2_wrreq),
        .WR2_ADDR(640*480),
        .WR2_MAX_ADDR(640*480*2),
        .WR2_LENGTH(256),
        .WR2_LOAD(~sys_rst_n),
        .WR2_CLK(sdr_wr2_clk),
        .WR2_FULL(),
        .WR2_USE(),

        // Read port1
        .RD1_DATA(sys_data_out1),
        .RD1(sys_rd1),
        .RD1_ADDR(0),
        .RD1_MAX_ADDR(640*480),
        .RD1_LENGTH(128),
        .RD1_LOAD(~sys_rst_n),
        .RD1_CLK(sdr_rd1_clk),
        .RD1_EMPTY(RD1_EMPTY),
        .RD1_USE(),

        // Read port2 (for VGA)
        .RD2_DATA(sys_data_out2),
        .RD2(sys_rd2),
        .RD2_ADDR(640*480),
        .RD2_MAX_ADDR(640*480*2),
        .RD2_LENGTH(128),
        .RD2_LOAD(~sys_rst_n),
        .RD2_CLK(sdr_rd2_clk),
        .RD2_EMPTY(RD2_EMPTY),
        .RD2_USE(),

        // SDRAM Side
        .SA(sdram_addr),
        .BA(sdram_ba),
        .CS_N(sdram_cs_n),
        .CKE(sdram_cke),
        .RAS_N(sdram_ras_n),
        .CAS_N(sdram_cas_n),
        .WE_N(sdram_we_n),
        .DQ(sdram_data),
        .SDR_CLK(sdram_clk),
        .DQM(sdram_dqm),
        .Sdram_Init_Done(sdram_init_done)
    );

    //---------------------------------------------
    // VGA Display
    //---------------------------------------------
    vga_display u_vga_display (
        .vga_clk    (clk_vga),
        .rst_n      (sys_rst_n),
		
        .fifo_data  (sys_data_out2),
        .fifo_empty (RD2_EMPTY),
        .fifo_rdreq (sys_rd2),   //读使能

        .vga_r      (vga_r),
        .vga_g      (vga_g),
        .vga_b      (vga_b),
        .vga_hs     (vga_hs),
        .vga_vs     (vga_vs),
        .vga_valid  ()
    );

endmodule
