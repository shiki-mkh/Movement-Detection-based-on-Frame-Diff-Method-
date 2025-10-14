`timescale 1ns/1ns
module I2C_ctrl #(
    parameter DEVICE_ADDR  = 7'b1010_000,
    parameter SYS_CLK_FREQ = 26'd50_000_000,
    parameter SCL_FREQ     = 18'd250_000
)(
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire        wr_en,
    input  wire        rd_en,
    input  wire        i2c_start,
    input  wire        addr_num,
    input  wire [15:0] byte_addr,
    input  wire [7:0]  wr_data,
    output reg         i2c_clk,
    output reg         i2c_end,
    output reg  [7:0]  rd_data,
    output reg         i2c_scl,
    inout  wire        i2c_sda
);

//======================================================================
// Parameter Definition
//======================================================================
    parameter CNT_CLK_MAX   = (SYS_CLK_FREQ / SCL_FREQ) >> 2'd3;
    parameter CNT_START_MAX = 8'd100;

    parameter IDLE          = 4'd00,
              START_1       = 4'd01,
              SEND_D_ADDR   = 4'd02,
              ACK_1         = 4'd03,
              SEND_B_ADDR_H = 4'd04,
              ACK_2         = 4'd05,
              SEND_B_ADDR_L = 4'd06,
              ACK_3         = 4'd07,
              WR_DATA       = 4'd08,
              ACK_4         = 4'd09,
              START_2       = 4'd10,
              SEND_RD_ADDR  = 4'd11,
              ACK_5         = 4'd12,
              RD_DATA       = 4'd13,
              N_ACK         = 4'd14,
              STOP          = 4'd15;

//======================================================================
// Signal Definition
//======================================================================
    wire        sda_in;
    wire        sda_en;

    reg  [7:0]  cnt_clk;
    reg  [3:0]  state;
    reg         cnt_i2c_clk_en;
    reg  [1:0]  cnt_i2c_clk;
    reg  [2:0]  cnt_bit;
    reg         ack;
    reg         i2c_sda_reg;
    reg  [7:0]  rd_data_reg;

//======================================================================
// I2C Clock Generation
//======================================================================
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            cnt_clk <= 8'd0;
        else if (cnt_clk == CNT_CLK_MAX - 1'b1)
            cnt_clk <= 8'd0;
        else
            cnt_clk <= cnt_clk + 1'b1;
    end

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            i2c_clk <= 1'b1;
        else if (cnt_clk == CNT_CLK_MAX - 1'b1)
            i2c_clk <= ~i2c_clk;
    end

//======================================================================
// I2C Sub-clock Enable and Counters
//======================================================================
    always @(posedge i2c_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            cnt_i2c_clk_en <= 1'b0;
        else if ((state == STOP) && (cnt_bit == 3'd3) && (cnt_i2c_clk == 3))
            cnt_i2c_clk_en <= 1'b0;
        else if (i2c_start == 1'b1)
            cnt_i2c_clk_en <= 1'b1;
    end

    always @(posedge i2c_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            cnt_i2c_clk <= 2'd0;
        else if (cnt_i2c_clk_en == 1'b1)
            cnt_i2c_clk <= cnt_i2c_clk + 1'b1;
    end

    always @(posedge i2c_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            cnt_bit <= 3'd0;
        else if ((state == IDLE) || (state == START_1) || (state == START_2) ||
                 (state == ACK_1) || (state == ACK_2) || (state == ACK_3) ||
                 (state == ACK_4) || (state == ACK_5) || (state == N_ACK))
            cnt_bit <= 3'd0;
        else if ((cnt_bit == 3'd7) && (cnt_i2c_clk == 2'd3))
            cnt_bit <= 3'd0;
        else if ((cnt_i2c_clk == 2'd3) && (state != IDLE))
            cnt_bit <= cnt_bit + 1'b1;
    end

//======================================================================
// I2C State Machine
//======================================================================
    always @(posedge i2c_clk or negedge sys_rst_n) begin
        if (!sys_rst_n)
            state <= IDLE;
        else begin
            case (state)
                IDLE:
                    if (i2c_start) state <= START_1;

                START_1:
                    if (cnt_i2c_clk == 3) state <= SEND_D_ADDR;

                SEND_D_ADDR:
                    if ((cnt_bit == 3'd7) && (cnt_i2c_clk == 3))
                        state <= ACK_1;

                ACK_1:
                    if ((cnt_i2c_clk == 3) && (ack == 1'b0))
                        state <= addr_num ? SEND_B_ADDR_H : SEND_B_ADDR_L;

                SEND_B_ADDR_H:
                    if ((cnt_bit == 3'd7) && (cnt_i2c_clk == 3))
                        state <= ACK_2;

                ACK_2:
                    if ((cnt_i2c_clk == 3) && (ack == 1'b0))
                        state <= SEND_B_ADDR_L;

                SEND_B_ADDR_L:
                    if ((cnt_bit == 3'd7) && (cnt_i2c_clk == 3))
                        state <= ACK_3;

                ACK_3:
                    if ((cnt_i2c_clk == 3) && (ack == 1'b0))
                        state <= wr_en ? WR_DATA : (rd_en ? START_2 : state);

                WR_DATA:
                    if ((cnt_bit == 3'd7) && (cnt_i2c_clk == 3))
                        state <= ACK_4;

                ACK_4:
                    if ((cnt_i2c_clk == 3) && (ack == 1'b0))
                        state <= STOP;

                START_2:
                    if (cnt_i2c_clk == 3) state <= SEND_RD_ADDR;

                SEND_RD_ADDR:
                    if ((cnt_bit == 3'd7) && (cnt_i2c_clk == 3))
                        state <= ACK_5;

                ACK_5:
                    if ((cnt_i2c_clk == 3) && (ack == 1'b0))
                        state <= RD_DATA;

                RD_DATA:
                    if ((cnt_bit == 3'd7) && (cnt_i2c_clk == 3))
                        state <= N_ACK;

                N_ACK:
                    if (cnt_i2c_clk == 3)
                        state <= STOP;

                STOP:
                    if ((cnt_bit == 3'd3) && (cnt_i2c_clk == 3))
                        state <= IDLE;

                default: state <= IDLE;
            endcase
        end
    end

//======================================================================
// ACK Signal Sampling
//======================================================================
    always @(*) begin
        case (state)
            IDLE, START_1, SEND_D_ADDR, SEND_B_ADDR_H, SEND_B_ADDR_L,
            WR_DATA, START_2, SEND_RD_ADDR, RD_DATA, N_ACK:
                ack = 1'b1;
            ACK_1, ACK_2, ACK_3, ACK_4, ACK_5:
                ack = (cnt_i2c_clk == 2'd0) ? sda_in : ack;
            default:
                ack = 1'b1;
        endcase
    end

//======================================================================
// SCL Generation
//======================================================================
    always @(*) begin
        case (state)
            IDLE:      i2c_scl = 1'b1;
            START_1:   i2c_scl = (cnt_i2c_clk == 3) ? 1'b0 : 1'b1;
            SEND_D_ADDR, ACK_1, SEND_B_ADDR_H, ACK_2, SEND_B_ADDR_L,
            ACK_3, WR_DATA, ACK_4, START_2, SEND_RD_ADDR, ACK_5, RD_DATA, N_ACK:
                       i2c_scl = ((cnt_i2c_clk == 2'd1) || (cnt_i2c_clk == 2'd2)) ? 1'b1 : 1'b0;
            STOP:      i2c_scl = ((cnt_bit == 3'd0) && (cnt_i2c_clk == 2'd0)) ? 1'b0 : 1'b1;
            default:   i2c_scl = 1'b1;
        endcase
    end

//======================================================================
// SDA Data Output Control
//======================================================================
    always @(*) begin
        case (state)
            IDLE: begin
                i2c_sda_reg <= 1'b1;
                rd_data_reg <= 8'd0;
            end

            START_1:
                i2c_sda_reg <= (cnt_i2c_clk <= 2'd0) ? 1'b1 : 1'b0;

            SEND_D_ADDR:
                i2c_sda_reg <= (cnt_bit <= 3'd6) ? DEVICE_ADDR[6 - cnt_bit] : 1'b0;

            ACK_1:
                i2c_sda_reg <= 1'b1;

            SEND_B_ADDR_H:
                i2c_sda_reg <= byte_addr[15 - cnt_bit];

            ACK_2:
                i2c_sda_reg <= 1'b1;

            SEND_B_ADDR_L:
                i2c_sda_reg <= byte_addr[7 - cnt_bit];

            ACK_3:
                i2c_sda_reg <= 1'b1;

            WR_DATA:
                i2c_sda_reg <= wr_data[7 - cnt_bit];

            ACK_4:
                i2c_sda_reg <= 1'b1;

            START_2:
                i2c_sda_reg <= (cnt_i2c_clk <= 2'd1) ? 1'b1 : 1'b0;

            SEND_RD_ADDR:
                i2c_sda_reg <= (cnt_bit <= 3'd6) ? DEVICE_ADDR[6 - cnt_bit] : 1'b1;

            ACK_5:
                i2c_sda_reg <= 1'b1;

            RD_DATA:
                if (cnt_i2c_clk == 2'd2)
                    rd_data_reg[7 - cnt_bit] <= sda_in;

            N_ACK:
                i2c_sda_reg <= 1'b1;

            STOP:
                i2c_sda_reg <= ((cnt_bit == 3'd0) && (cnt_i2c_clk < 2'd3)) ? 1'b0 : 1'b1;

            default: begin
                i2c_sda_reg <= 1'b1;
                rd_data_reg <= rd_data_reg;
            end
        endcase
    end

//======================================================================
// Data Output & End Flag
//======================================================================
    always @(posedge i2c_clk or negedge sys_rst_n)
        if (!sys_rst_n)
            rd_data <= 8'd0;
        else if ((state == RD_DATA) && (cnt_bit == 3'd7) && (cnt_i2c_clk == 2'd3))
            rd_data <= rd_data_reg;

    always @(posedge i2c_clk or negedge sys_rst_n)
        if (!sys_rst_n)
            i2c_end <= 1'b0;
        else if ((state == STOP) && (cnt_bit == 3'd3) && (cnt_i2c_clk == 3))
            i2c_end <= 1'b1;
        else
            i2c_end <= 1'b0;

//======================================================================
// SDA Bus Tri-state Control
//======================================================================
    assign sda_in  = i2c_sda;
    assign sda_en  = ((state == RD_DATA) || (state == ACK_1) || (state == ACK_2) ||
                      (state == ACK_3) || (state == ACK_4) || (state == ACK_5)) ? 1'b0 : 1'b1;
    assign i2c_sda = (sda_en == 1'b1) ? i2c_sda_reg : 1'bz;

endmodule
