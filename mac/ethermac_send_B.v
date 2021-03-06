/*************************************************************
File name   :mii_send.v
Function    :control the package send to PHY device
Author      :tongqing
Version     :V1.0
**************************************************************/	
module ethermac_send_B(
		input wire i_clk,
		input wire i_rst_n, 
		input wire i_SendIrq,
		input wire [15:0] i_data,
		input wire [9:0] i_length,
		output reg o_sendDn,
		output reg o_sendIdl,
		output reg [3:0] o_data,
		output reg o_EtxEn,
		output reg [9:0] o_data_addr,
		input  wire [1:0] i_port_id
);

parameter  PKG_MAX_LENGTH = 16'd757;


reg [4:0] fsm_cs;
reg [4:0] fsm_ns;
reg ram_wrEn; 

wire [15:0] ram_data_out;
reg [9:0] ram_rdNum;

reg [3:0] pre_num_counter;
wire [31:0] CRC; 

reg sendEn_dly1;
reg ram_wrEn_dly1;
reg ram_wrEn_dly2;
reg sendIdl;
reg [9:0] capacity;
reg [7:0] ifg_num;
reg reading_ram;
parameter IDLE                  = 5'b00000;
parameter SEND_START            = 5'b00001;
parameter SEND_PRE_NUM          = 5'b00011;
parameter SEND_START_NUM        = 5'b00010;
parameter SEND_1DATA            = 5'b00110;
parameter SEND_2DATA            = 5'b00111;
parameter SEND_3DATA            = 5'b00101;
parameter SEND_4DATA            = 5'b00100;
parameter SEND_1CRC             = 5'b01100;
parameter SEND_2CRC             = 5'b01101;
parameter SEND_3CRC             = 5'b01111;
parameter SEND_4CRC             = 5'b01110;
parameter SEND_5CRC             = 5'b01010;
parameter SEND_6CRC             = 5'b01011;
parameter SEND_7CRC             = 5'b01001;
parameter SEND_8CRC             = 5'b01000;
parameter SEND_OVER             = 5'b11000;
parameter WAIT_IFG              = 5'b11001;




/****************************************
 count the nibble number of preamble code
*****************************************/
always @ (posedge i_clk,negedge i_rst_n)
begin
    if (!i_rst_n)
    begin       
       pre_num_counter <= 4'h0;
    end
    else if (fsm_cs ==  SEND_PRE_NUM)
    begin
        pre_num_counter <= pre_num_counter +1'b1;
    end
    else
    begin
        pre_num_counter <= 4'h0;
    end
end



always @ (posedge i_clk,negedge i_rst_n)
begin
    if (!i_rst_n)
    begin
        reading_ram <= 1'h0;
    end
    else if (i_SendIrq)
    begin
        reading_ram <= 1'h1;
    end
    else if (o_data_addr >= i_length)
    begin
        reading_ram <= 1'h0;
    end
end


/********************************************
 count the byte number of the send package
 *********************************************/
always @ (posedge i_clk,negedge i_rst_n)
begin
    if (!i_rst_n)
    begin
        o_data_addr <= 10'h0;
    end
    else if (o_data_addr >= i_length)
    begin
        o_data_addr <= 10'h0;
    end
    else if (reading_ram)
    begin
        o_data_addr <= o_data_addr + 1'b1;
    end
	 else
    begin
        o_data_addr <= 10'h0;
    end	 
end


/*********************************************************
if word number in the send FIFO's is less than 3 ,then the
fifo_wrEn will be pull up,indicates that data can bewrite 
into FIFO. And if word number in the FIFO is more than
10,it will halt writing data into FIFO
******************************************************/
always @ (posedge i_clk , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin
        ram_wrEn <= 1'b0;
    end
    else if(o_data_addr >= i_length)
    begin
        ram_wrEn <= 1'b0;
    end
    else if (i_SendIrq)
    begin
        ram_wrEn <= 1'b1;
    end
end

/*************************************************
  1st always block, sequential state transition 
**************************************************/
always @ (posedge i_clk , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin
        fsm_cs <= IDLE;
    end
    else 
    begin
        fsm_cs  <= fsm_ns;
    end
end

/****************************************************
  2nd always block, combinational condition judgment
*****************************************************/
always @ (*)
begin 	
    case (fsm_cs)
    IDLE:
	 begin
        if (i_SendIrq && (i_length <= PKG_MAX_LENGTH))
		  fsm_ns = WAIT_IFG;
		  else
		  fsm_ns = IDLE;
	 end
	 WAIT_IFG:
    begin
        if((i_port_id == 2'b00) && (ifg_num >= 8'd13))
        fsm_ns = SEND_START;
        else if((i_port_id == 2'b01) && (ifg_num >= 8'd23))
        fsm_ns = SEND_START;
        else if((i_port_id == 2'b10) && (ifg_num >= 8'd33))
        fsm_ns = SEND_START;
        else
        fsm_ns = WAIT_IFG;
    end	 
    SEND_START:
        fsm_ns = SEND_PRE_NUM;
    SEND_PRE_NUM:
    begin
        if(pre_num_counter >= 4'he)
        fsm_ns = SEND_START_NUM;
        else 
        fsm_ns = SEND_PRE_NUM;
    end
    SEND_START_NUM:
        fsm_ns = SEND_1DATA;
    SEND_1DATA:
        fsm_ns = SEND_2DATA;
    SEND_2DATA:
        fsm_ns = SEND_3DATA;
    SEND_3DATA:
        fsm_ns = SEND_4DATA;
    SEND_4DATA:
    begin
        if (ram_rdNum >= i_length + 1'b1)
        fsm_ns = SEND_1CRC;
        else 
        fsm_ns = SEND_1DATA;
    end
    SEND_1CRC:
        fsm_ns = SEND_2CRC;
    SEND_2CRC:
        fsm_ns = SEND_3CRC;
    SEND_3CRC:
        fsm_ns = SEND_4CRC;
    SEND_4CRC:
        fsm_ns = SEND_5CRC;
    SEND_5CRC:
        fsm_ns = SEND_6CRC;
    SEND_6CRC:
        fsm_ns = SEND_7CRC;
    SEND_7CRC:
        fsm_ns = SEND_8CRC;
    SEND_8CRC:
        fsm_ns = SEND_OVER;
    SEND_OVER:
        fsm_ns = IDLE;
//    WAIT_1CLK:
//        NextState = WAIT_2CLK;
//    WAIT_2CLK:
//        NextState = IDLE;
    default:
        fsm_ns = IDLE;
    endcase
end
/**************************************************
    3rd always block, the combinational FSM output
***************************************************/
always @ (posedge i_clk , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin
        o_data <= 4'b0000;
        o_EtxEn <= 1'b0;
        o_sendDn <= 1'b0;
        o_sendIdl <= 1'b1;
		  ifg_num <= 8'h0;
    end
    else 
    case (fsm_ns)
    IDLE:
    begin
        o_sendDn <= 1'b0;
        o_EtxEn <= 1'b0; 
        o_sendIdl <= 1'b1;
        ram_rdNum <= 10'h0;
		  ifg_num <= 8'h0;
    end
	 WAIT_IFG:
    begin
        o_sendDn <= 1'b0;
        o_EtxEn <= 1'b0; 
        o_sendIdl <= 1'b1;
        ram_rdNum <= 10'h0;
        ifg_num <= ifg_num + 1'b1;
    end	 
    SEND_START:
    begin
        o_EtxEn <= 1'b0;  
        o_sendIdl <= 1'b0;
		  ram_rdNum <= 10'h1;
    end
    SEND_PRE_NUM:
    begin
        o_data <= 4'b0101;
        o_EtxEn <= 1'b1;
        o_sendIdl <= 1'b0;
    end                    
    SEND_START_NUM:
    begin
        o_data <= 4'b1101;
        o_sendIdl <= 1'b0;
    end 
    SEND_1DATA:
    begin
        o_data <= ram_data_out[11:8];
        o_sendIdl <= 1'b0;
    end
    SEND_2DATA:
    begin
        o_data <= ram_data_out[15:12];
        o_sendIdl <= 1'b0;
        ram_rdNum <= ram_rdNum + 1'b1;
    end                  
    SEND_3DATA:
    begin
        o_data <= ram_data_out[3:0];
        o_sendIdl <= 1'b0;
    end
    SEND_4DATA:
    begin
	     if(ram_rdNum == 10'd9)
            o_data    <= {ram_data_out[7:6], i_port_id};
        else
        begin
            o_data    <= ram_data_out[7:4];
            o_sendIdl <= 1'b0;
        end
    end
    SEND_1CRC:
    begin
         o_data <= {CRC[28],CRC[29],CRC[30],CRC[31]};
         o_sendIdl <= 1'b0;
    end
    SEND_2CRC:
    begin
        o_data <= {CRC[24],CRC[25],CRC[26],CRC[27]};
        o_sendIdl <= 1'b0;
    end
    SEND_3CRC:
    begin
        o_data <= {CRC[20],CRC[21],CRC[22],CRC[23]};
        o_sendIdl <= 1'b0;
    end
    SEND_4CRC:
    begin
        o_data <= {CRC[16],CRC[17],CRC[18],CRC[19]};
        o_sendIdl <= 1'b0;
    end
    SEND_5CRC:
    begin
        o_data <= {CRC[12],CRC[13],CRC[14],CRC[15]};
        o_sendIdl <= 1'b0;
    end
    SEND_6CRC:
    begin
        o_data <= {CRC[8],CRC[9],CRC[10],CRC[11]};
        o_sendIdl <= 1'b0;
    end
    SEND_7CRC:
    begin
       o_data <=  {CRC[4],CRC[5],CRC[6],CRC[7]};
       o_sendIdl <= 1'b0;
    end
    SEND_8CRC:
    begin
        o_data <= {CRC[0],CRC[1],CRC[2],CRC[3]};
        o_sendIdl <= 1'b0;
    end
    SEND_OVER:
    begin
        o_EtxEn <= 1'b0;
        o_data <= 4'b0000;
        o_sendDn <= 1'b1;
        o_sendIdl <= 1'b1;
        ram_rdNum <= 10'h0;
		  ifg_num <= 8'h0;
    end
    default:
    begin
        o_sendDn <= 1'b0;
        o_sendIdl <= 1'b1;
		  ifg_num <= 8'h0;
    end
    endcase
end

reg [15:0] data_for_crc;
reg        caculate_crc;
always @ (posedge i_clk , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin
        caculate_crc <= 1'b0;
        data_for_crc <= 16'b0;
    end
    else if(o_data_addr == 10'h8)
    begin
        caculate_crc <= ram_wrEn;
        data_for_crc <= {i_data[15:6], i_port_id, i_data[3:0]};
    end
    else
    begin
        caculate_crc <= ram_wrEn;
        data_for_crc <= i_data;
    end
end

send_cache_B   send_ram_B
(
	.clock(i_clk),
	.data(i_data),
	.rdaddress(ram_rdNum),
	.wraddress(o_data_addr),
	.wren(ram_wrEn),
	.q(ram_data_out)
);

ethmac_add_crc_B ethmac_add_crc_B(
		 .i_clk(i_clk), 
		 .i_rst_n(i_rst_n),
		 .i_crc_reset(i_SendIrq), 
		 .i_data(data_for_crc), 
		 .i_crc_enable(caculate_crc), 
		 .o_crc(CRC) 
);

endmodule
