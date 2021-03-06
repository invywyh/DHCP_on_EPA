module ethermac_recv_B
(input wire i_clk,
 input wire i_rst_n, 
 input wire [47:0] i_local_node_mac,
 input wire [3:0] i_data, 
 input wire i_ErxDv,
 input wire i_fifo_reset_n,
 output wire [15:0] o_data,
 output reg o_data_valid,
 output reg [9:0] o_recv_addr,
 input wire i_initDn,
 input wire i_csme_en,

/*************************  sjj Nov_6th   *************************/	 
 input wire [9:0] i_length,
/*************************  sjj Nov_6th   *************************/	


// input wire i_main_clock_lost,
// input wire i_main_clock_state,
// input wire i_start_en

 //20140224 to ignore illegal package
 input  wire i_send_alarm_to_pdo_A,
 input  wire i_send_alarm_to_pdo_B,
 input  wire i_pack_safe_A,
 input  wire i_pack_safe_B
);

/***************************************/
reg[3:0] fsm_ram_wr_cs;
reg[3:0] fsm_ram_wr_ns;
reg[2:0] fsm_ram_rd_cs;
reg[2:0] fsm_ram_rd_ns;

reg ram_wrEn;
reg ram_rdEn;
reg [15:0] ram_data_in;
reg [9:0] ram_wrNum;

reg [9:0] rdaddress;
reg [9:0] wraddress;
reg [9:0] address_head[9:0];
reg [9:0] len_pack[9:0];
reg [3:0] wrnum;
reg [3:0] rdnum;
wire [3:0] wrnum_next;
reg [3:0] rdnum_before;
reg initDn_dly1;
reg ErxDv_dly1;
reg o_pre_err;
/***************************************/
wire recv_keep;
wire [31:0] o_crc; 
wire crc_reset;
reg recvEn_dly1;
reg [9:0] wordNum;
reg [15:0] pre_cn;
reg crc_err;
parameter IDLE                  = 4'b0000;
parameter RECV_PRENUM           = 4'b0001;
parameter RECV_START            = 4'b0011;
parameter RECV_1DATA            = 4'b0010;
parameter RECV_2DATA            = 4'b0110;
parameter RECV_3DATA            = 4'b0111;
parameter RECV_4DATA            = 4'b0101;
parameter STORE_DN              = 4'b0100;
parameter WAIT_CHECK				  = 4'b1100;		//modified by guhao 20140217
parameter MARK_ADDR             = 4'b1000;

parameter O_RAM_IDLE            = 3'b000;
parameter O_RAM_START           = 3'b001;
parameter O_RAM_DATA            = 3'b011;
parameter REMOVE_CRC            = 3'b010;
parameter READ_DN               = 3'b110;


assign crc_reset = (fsm_ram_wr_cs == STORE_DN) ? 1'b1 : 1'b0;

/****************************************
 count the nibble number of preamble code
*****************************************/
always @ (posedge i_clk , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin
		pre_cn <= 16'h0;
	end
	else if (fsm_ram_wr_cs == RECV_PRENUM)
	begin
		pre_cn <= pre_cn + 1'b1;
	end
	else 
    begin
		pre_cn <= 16'h0;
	end
end	
/*****************************************
if the recv_state is stay in the preamble for 
a long time (more than ten i_ErxClk),then it 
will notice a receive error
********************************************/
always @ (posedge i_clk , negedge i_rst_n)
begin
	if (!i_rst_n)
    begin
		o_pre_err <= 1'b0;
	end
	else if (pre_cn >= 16'h12)
	begin
		o_pre_err <= 1'b1;
	end
	else
	begin
		o_pre_err <= 1'b0;
	end
end

/*************************************************************
to synchronize the following signals with i_ErxClk for 2 times
*************************************************************/
always @ (posedge i_clk , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin
        ErxDv_dly1 <= 1'b0;

    end
    else
    begin
        ErxDv_dly1 <= i_ErxDv;

    end
end
/************************************************************
  1st always block, sequential state transition (write FIFO)
************************************************************/
always @ (posedge i_clk  , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin
        fsm_ram_wr_cs <= IDLE;
    end
    else 
    begin
        fsm_ram_wr_cs  <= fsm_ram_wr_ns;
    end
end

/************************************************************
  2nd always block, combinational condition judgment(write RAM),
  if init has done,the i_ErxDv will be function,and then the 
  ram can begin to receive the packages
*************************************************************/
always @ (*)
begin 
    case (fsm_ram_wr_cs)
    IDLE:
	 if (i_initDn && (!ErxDv_dly1 && i_ErxDv))
        fsm_ram_wr_ns = RECV_PRENUM;
	 else
	     fsm_ram_wr_ns = IDLE;
    RECV_PRENUM:
    begin
        if (o_pre_err)
		      fsm_ram_wr_ns = STORE_DN;
		  else if ((i_data == 4'b1101) && i_ErxDv)
            fsm_ram_wr_ns = RECV_START;
        else 
            fsm_ram_wr_ns = RECV_PRENUM;
    end
    RECV_START:
        fsm_ram_wr_ns = RECV_1DATA;
    RECV_1DATA:
        fsm_ram_wr_ns = RECV_2DATA;
    RECV_2DATA:
        fsm_ram_wr_ns = RECV_3DATA;
    RECV_3DATA:
        fsm_ram_wr_ns = RECV_4DATA;
    RECV_4DATA:
    begin
       if (ram_wrNum > 10'h2f9)
		      fsm_ram_wr_ns = IDLE;
		 else if (!recv_keep || !i_ErxDv)                   //recv_keep is a constant "1".
/*************************  sjj Nov_6th   *************************/
//		 else if (!recv_keep || !i_ErxDv || (ram_wrNum >= i_length  )) 
/*************************  sjj Nov_6th   *************************/		 
		      fsm_ram_wr_ns = STORE_DN;
		 else 
            fsm_ram_wr_ns = RECV_1DATA;
    end
    STORE_DN:		//modified 20140217
	     if ((ram_wrNum >= 10'h20) && (ram_wrNum <= 10'h2f9))
				fsm_ram_wr_ns = WAIT_CHECK;
		  else
		      fsm_ram_wr_ns = IDLE;
	 WAIT_CHECK:
		  if(i_pack_safe_A || i_pack_safe_B)
				fsm_ram_wr_ns = MARK_ADDR;
		  else if(i_send_alarm_to_pdo_A || i_send_alarm_to_pdo_B)
				fsm_ram_wr_ns = IDLE;
		  else
				fsm_ram_wr_ns = WAIT_CHECK;
//    STORE_DN:
//	     if ((ram_wrNum >= 10'h20) && (ram_wrNum <= 10'h2f9))
//				fsm_ram_wr_ns = MARK_ADDR;
//		  else
//		      fsm_ram_wr_ns = IDLE;
	 MARK_ADDR:
	     fsm_ram_wr_ns = IDLE;
    default:
        fsm_ram_wr_ns = IDLE;
    endcase
end
    
/******************************************************
  piece together the 4 bits data received from PHY
  to become 16 bits data and store into RAM
*******************************************************/
always @ (posedge i_clk  , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin 
        ram_data_in <= 16'h0;
    end
    else 
    case (fsm_ram_wr_ns)
    IDLE,RECV_START,RECV_PRENUM,STORE_DN,MARK_ADDR:
    begin
        ram_data_in <= 16'h0;
    end
    RECV_1DATA:         
    begin
        ram_data_in[11:8] <= i_data;
    end
    RECV_2DATA:        
    begin
        ram_data_in[15:12] <= i_data; 
    end
    RECV_3DATA:         
    begin
        ram_data_in[3:0] <= i_data; 
    end
    RECV_4DATA:        
    begin
        ram_data_in[7:4] <= i_data; 
    end
    default:
    begin
        ram_data_in <= 16'h0;
    end
    endcase
end
/*****************************************************
when finished receiving a byte data,then the
ram_wrEn will be pull up,indicates that data can be
write into RAM.
******************************************************/
always @ (posedge i_clk  , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin 
        ram_wrEn <= 1'b0;
    end
    else 
    case (fsm_ram_wr_ns)
    IDLE,RECV_START,RECV_PRENUM,RECV_1DATA,RECV_2DATA,RECV_3DATA,STORE_DN,MARK_ADDR:
    begin
        ram_wrEn <= 1'b0;
    end                     
    RECV_4DATA:         //6
    begin
        ram_wrEn <= 1'b1;
    end
    default:
    begin
        ram_wrEn <= 1'b0;
    end
    endcase
end
/********************************************
 count the byte number of the received package,
 and get the written address of the received
 package
 *********************************************/
always @ (posedge i_clk  , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin 
        ram_wrNum <= 10'h0;
		  wraddress <= 10'h0;
    end
    else 
    case (fsm_ram_wr_ns)
//    RECV_1DATA,RECV_2DATA,RECV_3DATA,STORE_DN,MARK_ADDR:	//20140226
	 RECV_1DATA,RECV_2DATA,RECV_3DATA,STORE_DN,WAIT_CHECK,MARK_ADDR:
    begin
    ram_wrNum <= ram_wrNum;
	 wraddress <= wraddress;
    end
    IDLE,RECV_START,RECV_PRENUM:
    begin
    ram_wrNum <= 10'h0;
	 wraddress <= wraddress;
    end
    RECV_4DATA:       
    begin
        ram_wrNum <= ram_wrNum + 1'b1;
		  if(wraddress < 10'h3fe)
		  begin
		    wraddress <= wraddress + 1'b1;
		  end
		  else if(wraddress == 10'h3fe)
		  begin
		    wraddress <= 10'h0;
		  end
    end
    default:
    begin
        ram_wrNum <= 10'h0;
		  wraddress <= wraddress;
    end
    endcase
end

assign wrnum_next = wrnum + 1'b1;
/*****************************************************
through the written address,get the address head and length 
of each received package,and let the next buffer value of 
the memory be 10'h3ff so that reading state can make the judge 
of when to begin reading
*****************************************************/
always @ (posedge i_clk  , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin 
        address_head[0]  <= 10'h3ff;
		  address_head[1]  <= 10'h3ff;
		  address_head[2]  <= 10'h3ff;
		  address_head[3]  <= 10'h3ff;
		  address_head[4]  <= 10'h3ff;
		  address_head[5]  <= 10'h3ff;
		  address_head[6]  <= 10'h3ff;
		  address_head[7]  <= 10'h3ff;
		  address_head[8]  <= 10'h3ff;
		  address_head[9]  <= 10'h3ff;
		  len_pack[0]     <= 10'h0;
		  len_pack[1]     <= 10'h0;
		  len_pack[2]     <= 10'h0;
		  len_pack[3]     <= 10'h0;
		  len_pack[4]     <= 10'h0;
		  len_pack[5]     <= 10'h0;
		  len_pack[6]     <= 10'h0;
		  len_pack[7]     <= 10'h0;
		  len_pack[8]      <= 10'h0;
		  len_pack[9]      <= 10'h0;
		  wrnum            <= 4'h0;
    end
    else 
    case (fsm_ram_wr_ns)
    RECV_PRENUM:
	 begin
	 if(wrnum < 4'h9)
	  begin
	  address_head[wrnum_next] <= 10'h3ff;
	  end
	 else if(wrnum == 4'h9)
	  begin
	  address_head[0] <= 10'h3ff;
	  end
	 end
	 IDLE,RECV_START,RECV_1DATA,RECV_2DATA,RECV_3DATA,STORE_DN:
    begin
        address_head[0]  <= address_head[0];
		  address_head[1]  <= address_head[1];
		  address_head[2]  <= address_head[2];
		  address_head[3]  <= address_head[3];
		  address_head[4]  <= address_head[4];
		  address_head[5]  <= address_head[5];
		  address_head[6]  <= address_head[6];
		  address_head[7]  <= address_head[7];
		  address_head[8]  <= address_head[8];
		  address_head[9]  <= address_head[9];
		  len_pack[0]      <= len_pack[0];
		  len_pack[1]      <= len_pack[1];
		  len_pack[2]      <= len_pack[2];
		  len_pack[3]      <= len_pack[3];
		  len_pack[4]      <= len_pack[4];
		  len_pack[5]      <= len_pack[5];
		  len_pack[6]      <= len_pack[6];
		  len_pack[7]      <= len_pack[7];
		  len_pack[8]      <= len_pack[8];
		  len_pack[9]      <= len_pack[9];
	     wrnum           <= wrnum;
    end
	 MARK_ADDR:
	 begin
	       if(((recv_keep == 1'b1) && (crc_err == 1'b0)) && (wrnum < 4'h9) && (wraddress < ram_wrNum - 1'b1))
			  begin
			  address_head[wrnum] <= wraddress + 1'b1 + 10'h3ff - ram_wrNum;
			  len_pack[wrnum]     <= ram_wrNum;
			  wrnum               <= wrnum + 4'h1;
			  end
			 else if(((recv_keep == 1'b1) && (crc_err == 1'b0)) && (wrnum < 4'h9) && (wraddress >= ram_wrNum - 1'b1))
			  begin
			  address_head[wrnum] <= wraddress + 1'b1 - ram_wrNum;
			  len_pack[wrnum]     <= ram_wrNum;
			  wrnum               <= wrnum + 4'h1;
			  end
			 else if(((recv_keep == 1'b1) && (crc_err == 1'b0)) && (wrnum == 4'h9) && (wraddress < ram_wrNum - 1'b1))
			  begin
			  address_head[wrnum] <= wraddress - ram_wrNum + 1'b1 + 10'h3ff;
			  len_pack[wrnum]     <= ram_wrNum;
			  wrnum               <= 4'h0;
			  end
			 else if(((recv_keep == 1'b1) && (crc_err == 1'b0)) && (wrnum == 4'h9) && (wraddress >= ram_wrNum - 1'b1))
			  begin
			  address_head[wrnum] <= wraddress + 1'b1 - ram_wrNum;
			  len_pack[wrnum]     <= ram_wrNum;
			  wrnum               <= 4'h0;
			  end
			 else
			  begin
			  address_head[wrnum] <= address_head[wrnum];
			  len_pack[wrnum]     <= len_pack[wrnum];
			  wrnum               <= wrnum;
			  end
	 end
    default:
    begin
        address_head[0]  <= address_head[0];
		  address_head[1]  <= address_head[1];
		  address_head[2]  <= address_head[2];
		  address_head[3]  <= address_head[3];
		  address_head[4]  <= address_head[4];
		  address_head[5]  <= address_head[5];
		  address_head[6]  <= address_head[6];
		  address_head[7]  <= address_head[7];
		  address_head[8]  <= address_head[8];
		  address_head[9]  <= address_head[9];
		  len_pack[0]      <= len_pack[0];
		  len_pack[1]      <= len_pack[1];
		  len_pack[2]      <= len_pack[2];
		  len_pack[3]      <= len_pack[3];
		  len_pack[4]      <= len_pack[4];
		  len_pack[5]      <= len_pack[5];
		  len_pack[6]      <= len_pack[6];
		  len_pack[7]      <= len_pack[7];
		  len_pack[8]      <= len_pack[8];
		  len_pack[9]      <= len_pack[9];
		  wrnum           <= wrnum;
    end
    endcase
end

/******************************************************
  1st always block, sequential state transition (read RAM)
******************************************************/
always @ (posedge i_clk  , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin
        fsm_ram_rd_cs <= O_RAM_IDLE;
    end
    else 
    begin
        fsm_ram_rd_cs  <= fsm_ram_rd_ns;
    end
end

/***********************************************************
  2nd always block, combinational condition judgment(read RAM)
************************************************************/
always @ (*)
begin  
    case (fsm_ram_rd_cs)
    O_RAM_IDLE:
        if ((address_head[rdnum] != 10'h3ff) && i_initDn)
		  begin
		  fsm_ram_rd_ns = O_RAM_START;
		  end
        else 
        fsm_ram_rd_ns = O_RAM_IDLE;
    O_RAM_START:
        fsm_ram_rd_ns = O_RAM_DATA;
    O_RAM_DATA:
	     
		  begin
         if ((o_recv_addr == (len_pack[rdnum_before] - 2'b10 - 2'b1)) && (len_pack[rdnum_before] != 10'h0))
//         if ((o_recv_addr == (len_pack[rdnum_before] - 2'b10 )) && (len_pack[rdnum_before] != 10'h0)) // Nov_11st
         fsm_ram_rd_ns = REMOVE_CRC;
        else
         fsm_ram_rd_ns = O_RAM_DATA;
		  end
    REMOVE_CRC:
        fsm_ram_rd_ns = READ_DN;
    READ_DN:
        fsm_ram_rd_ns = O_RAM_IDLE;
    default:
        fsm_ram_rd_ns = O_RAM_IDLE; 
    endcase
end

/*********************************************
control data reading  from RAM ,if ram_rdEn =1,
then it is enable to read data from RAM;and when
reading data,the reading address will twine itself
********************************************/
always @ (posedge i_clk  , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin 
        ram_rdEn  <= 1'b0;
		  rdnum     <= 4'h0;
		  rdaddress <= 10'h3ff;
		  rdnum_before <= 4'h9;
	 end
    else 
    case (fsm_ram_rd_ns)
    O_RAM_IDLE:
	 begin
		  ram_rdEn <= 1'b0;
		  rdnum    <= rdnum;
    end  
	 O_RAM_START:
	 begin
		  rdaddress <= address_head[rdnum];
		  ram_rdEn  <= 1'b1;
		  if(rdnum < 4'h9)
		  begin
		  rdnum    <= rdnum + 4'h1;
		  rdnum_before <= rdnum;
		  end
		  else if(rdnum == 4'h9)
		  begin
		  rdnum    <= 4'h0;
		  rdnum_before <= 4'h9;
		  end
	 end
    O_RAM_DATA,REMOVE_CRC:
    begin
		  ram_rdEn <= 1'b1;
		  rdnum    <= rdnum;
		  if(rdaddress < 10'h3fe)
		  rdaddress <= rdaddress + 10'h1;
		  else if(rdaddress == 10'h3fe)
		  rdaddress <= 10'h0;
    end
	 READ_DN:
    begin
        ram_rdEn <= 1'b0;
		  rdnum    <= rdnum;
		  rdaddress <= rdaddress;
    end   
    default:
    begin
		  ram_rdEn <= 1'b0;
		  rdaddress <= rdaddress;
		  rdnum    <= rdnum;
    end
    endcase
end

/**************************************
  give the address of data received
*************************************/
always @ (posedge i_clk  , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin 
        o_recv_addr <= 10'h0;
    end
    else if (fsm_ram_rd_cs == O_RAM_DATA)
    begin
        o_recv_addr <= o_recv_addr + 1'b1;
    end
    else if (fsm_ram_rd_cs == READ_DN)
    begin
        o_recv_addr <= 10'h0;
    end
end
/******************************************************
o_data_valid=1 indicates that the output o_data is valid
*******************************************************/ 
always @ (posedge i_clk  , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin 
        o_data_valid <= 1'b0;
    end
    else if (fsm_ram_rd_cs == O_RAM_DATA)
    begin
        o_data_valid <= 1'b1;
    end
    else
    begin 
        o_data_valid <= 1'b0;
    end
end    
/**********************************************************
judge CRC value.if CRC wrong,then notice to give up the package
**********************************************************/
 always @ (posedge i_clk , negedge i_rst_n)
begin
    if (!i_rst_n)
    begin
        crc_err <= 1'b0;
    end
    else if (recv_keep && (fsm_ram_wr_cs == STORE_DN) && (o_crc != 32'hc704dd7b))
    begin
        crc_err <= 1'b1;
    end
    else if (fsm_ram_wr_cs == IDLE)
    begin
        crc_err <= 1'b0;
    end
end

addrcheck_B addrcheck_inst_B
(.i_clk(i_clk), 
 .i_rst_n(i_rst_n), 
 .i_rx_data(ram_data_in),
 .i_wordNum(ram_wrNum),
 .i_data_valid(ram_wrEn),
 .i_recvDn(),
 .o_recv_keep(recv_keep),
 .i_csme_en(i_csme_en),
 .i_local_node_mac(i_local_node_mac)
// .i_main_clock_lost(i_main_clock_lost),
// .i_main_clock_state(i_main_clock_state),
// .i_start_en(i_start_en)
); 

CRC_judge_recv_B CRC_judge_recv_inst_B
(.i_clk(i_clk),
 .i_rst_n(i_rst_n), 
 .i_data(ram_data_in),
 .i_data_valid(ram_wrEn),
 .i_crc_reset(crc_reset), 
 .o_crc(o_crc)
);

ram_recv_B ram_recv_B
(
	.aclr(!i_rst_n),
	.clock(i_clk),
	.data(ram_data_in),
	.rdaddress(rdaddress),
	.rden(ram_rdEn),
	.wraddress(wraddress),
	.wren(ram_wrEn),
	.q(o_data)
	);

endmodule
