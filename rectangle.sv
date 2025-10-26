`timescale 1ns/1ns
module rectangle
#(
	parameter	[10:0]	IMG_WIDTH = 11'd640,	//640*480
	parameter	[10:0]	IMG_HEIGHT  = 11'd480
)
(
	//global clock
	input				clk,  				//cmos video pixel clock
	input				rst_n,				//global reset

	//Image data prepred to be processd
	input				per_frame_vsync,	//Prepared Image data vsync valid signal
	input				per_frame_href,		//Prepared Image data href vaild  signal
	input				per_frame_clken,	//Prepared Image data output/capture enable clock
	input		      per_img_Y,			//Prepared Image brightness input
	
	input          cmos_frame_clken,	               
	input          cmos_frame_vsync,	
	input          cmos_frame_href,	
	input  [15:0]  cmos_frame_data, 
	
	//Image data has been processd
	output			post_frame_vsync,	//Processed Image data vsync valid signal
	output			post_frame_href,	//Processed Image data href vaild  signal
	output			post_frame_clken,	//Processed Image data output/capture enable clock
	output [15:0]  post_img_Y			//Processed Image brightness output
);
wire         out_en_h  ;
wire         out_en_v   ;

reg [9:0]   edg_up     ;// = 160;
reg [9:0]   edg_down   ;// = 240;
reg  [9:0]  edg_left   ;//= 160 ;
reg  [9:0]  edg_right  ;//= 240;

reg [9:0]   edg_up_d1     ;// = 160;
reg [9:0]   edg_down_d1   ;// = 240;
reg  [9:0]  edg_left_d1   ;//= 160 ;
reg  [9:0]  edg_right_d1  ;//= 240;




reg per_frame_href_r    ;
reg per_frame_vsync_r   ;
reg per_frame_clken_r;
reg per_img_data_r;
reg [9:0]h_cnt;
reg [9:0]v_cnt;
reg [15:0]  post_cmos_data;
wire valid_en = 1'b1;//out_en_v &out_en_h ;
wire href_falling;
wire vsync_rising;
wire vsync_falling;

// reg per_frame_href_r ;
// reg per_frame_vsync_r;
//per_img_data_r|post_frame_href_tmp，sample clk
always@(posedge clk or negedge rst_n)
 if(!rst_n)begin
   per_frame_href_r<= 1'd0;
   per_frame_vsync_r<= 1'd0;
	per_frame_clken_r <= 1'b0;
   per_img_data_r <=1'd0;
   end 
 else begin
   per_frame_href_r<= per_frame_href; 
   per_frame_vsync_r<= per_frame_vsync; 
   per_img_data_r <=per_img_Y;
	per_frame_clken_r <= per_frame_clken;
 end 
 
reg         cmos_frame_clken_r;	               
reg         cmos_frame_vsync_r;	
reg         cmos_frame_href_r;
 
 always@(posedge clk or negedge rst_n)
 if(!rst_n)begin
   cmos_frame_href_r  <= 1'd0;
   cmos_frame_vsync_r <= 1'd0;
	cmos_frame_clken_r <= 1'b0;
   end 
 else begin
   cmos_frame_href_r  <= cmos_frame_href;
   cmos_frame_vsync_r <= cmos_frame_vsync;
	cmos_frame_clken_r <= cmos_frame_clken;
 end 
 
//wire     vsync_falling;
//---------h,v-cnt-----------------------------
// reg [9:0]h_cnt;
// reg [9:0]v_cnt;
always@(posedge clk or negedge rst_n)
 if(!rst_n)begin
 h_cnt <=10'd0;
 end
 else if(per_frame_href)begin
  if(per_frame_clken)
    h_cnt <=h_cnt+1'b1;
  else
    h_cnt <=h_cnt;
 end 
 else begin
 h_cnt <=10'd0;
 end 
 
 always@(posedge clk or negedge rst_n)
 if(!rst_n)begin
 v_cnt <=10'd0;
 end
 else if(per_frame_vsync)begin 
  if(href_falling)
  v_cnt <=v_cnt+1'b1;
  else
  v_cnt <=v_cnt;
 end 
 else 
 v_cnt <=10'd0;
 

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n) begin
      edg_up    <=  10'd479;
      edg_down  <=  10'd0;
      edg_left  <=  10'd639;
      edg_right <=  10'd0;
	 end
	else if(vsync_rising) begin
	   edg_up    <=  10'd479;
      edg_down  <=  10'd0;
      edg_left  <=  10'd639;
      edg_right <=  10'd0;
	end
   else if(per_frame_clken & per_frame_href)begin
	  if(per_img_Y == 1'b1) begin
	     if(edg_up > v_cnt)
	       edg_up  <=v_cnt ;
	     else 
          edg_up  <=edg_up ;	
	
	     if(edg_down < v_cnt)
	       edg_down  <=v_cnt ;
	     else 
          edg_down  <=edg_down ;	
			 
		  if(edg_left > h_cnt)
	       edg_left  <= h_cnt ;
	     else 
          edg_left  <=edg_left ;	
	
	     if(edg_right < h_cnt)
	       edg_right  <=h_cnt ;
	     else 
          edg_right  <=edg_right ;			 
	  end
	end
end 
 
always@(posedge clk or negedge rst_n)
begin 
   if(!rst_n) begin
      edg_up_d1    <=  10'd160;
      edg_down_d1  <=  10'd240;
      edg_left_d1  <=  10'd160;
      edg_right_d1 <=  10'd240;
	 end
 	else if(vsync_falling) begin
	   edg_up_d1    <=  edg_up   ;
      edg_down_d1  <=  edg_down ;
      edg_left_d1  <=  edg_left ;
      edg_right_d1 <=  edg_right;
	end
end 
 
 
// 标记
 // reg [7:0]  post_cmos_data;
always@(posedge  clk or negedge rst_n)
begin
    if(!rst_n) 
	 post_cmos_data <= 16'd0; 
else if(cmos_frame_vsync)begin 
    if(~(cmos_frame_href & cmos_frame_clken)) 
	 post_cmos_data <= 16'd0;
    else if(valid_en &&
	      ((((( h_cnt >=edg_left_d1)&&(h_cnt <=edg_left_d1+3))||(( h_cnt >=edg_right_d1))&&(h_cnt <=edg_right_d1+3)))&&(v_cnt >=edg_up_d1 && v_cnt <= edg_down_d1))
		 ||(((( v_cnt >=edg_up_d1)&&(v_cnt <=edg_up_d1+3))||(( v_cnt >=edg_down_d1)&&(v_cnt <=edg_down_d1+3)))&&(h_cnt >= edg_left_d1 && h_cnt <= edg_right_d1)))
	 post_cmos_data <={5'b11111,6'd0,5'd0};
    else  
	 post_cmos_data <= cmos_frame_data;///{16{per_img_Y}};// //per_img_data_r;//
  end 
end
assign     vsync_rising    =(~per_frame_vsync_r) & per_frame_vsync ?1'b1:1'b0;
assign     vsync_falling   = per_frame_vsync_r & (~per_frame_vsync)? 1'b1:1'b0;
assign     href_falling    = per_frame_href_r & (~per_frame_href)?1'b1:1'b0;

//assign post_frame_vsync =per_frame_vsync_r;
//assign post_frame_href  =per_frame_href_r;
//assign post_frame_clken  = per_frame_clken_r;

assign post_frame_vsync  = cmos_frame_vsync_r;
assign post_frame_href   = cmos_frame_href_r;
assign post_frame_clken  = cmos_frame_clken_r;



assign post_img_Y =post_cmos_data;

endmodule
