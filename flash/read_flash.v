`include "../master_rtl/define/define.v"
module read_flash
(
 input wire i_clk,
 input wire i_rst_n, 
 input wire i_rd_irq,
 inout wire b_sda,
 output reg [15:0] o_flash_data,
 output reg o_flash_rd_en,
 output reg [`ADDR_SZ-1:0] o_flash_raddr,     //Modified by SYF 2014.5.20
 output reg o_flash_read_done,
 output reg o_scl
);

parameter IDLE_FLASH = 5'b0000;
parameter I2C_INIT = 5'b0001; 
parameter I2C_START = 5'b0011;
parameter FLASH_ADDR_READY = 5'b0010; 
parameter PSEUDO_WRITE = 5'b0110; 
parameter START_ADDRH = 5'b0111;
parameter START_ADDRL = 5'b0101;
parameter I2C_INIT_AGAIN = 5'b0100;
parameter I2C_START_AGAIN = 5'b1100;
parameter ADDR_READY_AGAIN = 5'b1101;
parameter FLASH_ADDR = 5'b1111;
parameter RECV_DATAH = 5'b1110;
parameter SEND_ACK1 = 5'b1010;
parameter RECV_DATAL = 5'b1011;
parameter SEND_ACK2 = 5'b1001;

parameter READY_STOP = 5'b1000;
parameter STOP_SIGNAL = 5'b11000;
parameter READ_DONE = 5'b11001;

parameter I2C_IDLE_AGAIN = 5'b11011;
parameter frequency = 8'hf9;


reg [4:0] fsm_FLASH_cs;
reg [4:0] fsm_FLASH_ns/*synthesis noprune*/;

reg [7:0] freq_cn;
reg [3:0] bit_cn;
reg [`ADDR_SZ-1:0] total_word_cn;    //Modified by SYF 2014.5.20
reg scl_en;
reg [7:0] flash_addr;
wire [7:0] start_addrh;
wire [7:0] start_addrl;

reg sda_recv;
reg [7:0] clk_cn;
reg jump_en;
reg scl_dly1;
reg [7:0]tbuf;
assign b_sda = sda_recv;
assign start_addrh = 8'h0;
assign start_addrl = 8'h0;

always @ (posedge i_clk,negedge i_rst_n)
begin
	if (!i_rst_n)
	begin
	    scl_dly1 <= 1'b0;
	end
	else
	begin
	   scl_dly1 <= o_scl;
	end
end 

always @ (posedge i_clk,negedge i_rst_n)
begin
	if (!i_rst_n)
	begin
	    clk_cn <= 8'h0;
	end
	else if (fsm_FLASH_cs != fsm_FLASH_ns)
	begin
	    clk_cn <= 8'h0;
	end
	else
	begin
	   clk_cn <= clk_cn + 1'b1;
	end
end 
always @ (posedge i_clk,negedge i_rst_n)
begin
	if (!i_rst_n)
	begin
	    jump_en <= 1'b0;
	end
	else if (fsm_FLASH_cs != fsm_FLASH_ns)
	begin
	    jump_en <= 1'b0;
	end
	else if (clk_cn == 8'h80)
	begin
	    jump_en <= 1'b1;
	end
	else
	begin
	    jump_en <= 1'b0;
	end
end

always @ (posedge i_clk,negedge i_rst_n)
begin
    if (!i_rst_n)
    begin
		flash_addr <= 8'hff;
	end
	else if (fsm_FLASH_ns == I2C_INIT)
	begin
		flash_addr <= 8'b10100000;
	end
	else if (fsm_FLASH_ns == I2C_INIT_AGAIN)
	begin
		flash_addr <= 8'b10100001;
	end
end
	
always @ (posedge i_clk,negedge i_rst_n)
begin
	if (!i_rst_n)
	begin
		fsm_FLASH_cs <= IDLE_FLASH;
	end
	else 
	begin
		fsm_FLASH_cs <= fsm_FLASH_ns;
	end
end

always @ (*)
begin
	if (!i_rst_n)
	begin
		fsm_FLASH_ns = IDLE_FLASH;
	end
	else
	case(fsm_FLASH_cs)
	IDLE_FLASH:
	begin
		if (i_rd_irq)
		begin
			fsm_FLASH_ns = I2C_INIT;
		end
		else
		begin
			fsm_FLASH_ns = IDLE_FLASH;
		end
	end
	I2C_INIT:
	begin
	   if (jump_en)
		    fsm_FLASH_ns = I2C_START;
		else
		    fsm_FLASH_ns = I2C_INIT;
	end
	I2C_START:
	begin
		if (jump_en)
		begin
		    fsm_FLASH_ns = FLASH_ADDR_READY;
		end
		else
		begin
			fsm_FLASH_ns = I2C_START;
		end
	end
	FLASH_ADDR_READY:
	begin
	    fsm_FLASH_ns = PSEUDO_WRITE;
	end
	PSEUDO_WRITE:
	begin
		if ((bit_cn == 4'b0000)&&(freq_cn == frequency))
		begin
			fsm_FLASH_ns = START_ADDRH;
		end
		else 
		begin
			fsm_FLASH_ns = PSEUDO_WRITE;
		end
	end
	START_ADDRH:
	begin
		if ((bit_cn == 4'b0000)&&(freq_cn == frequency))
		begin
			fsm_FLASH_ns = START_ADDRL;
		end
		else 
		begin
			fsm_FLASH_ns = START_ADDRH;
		end
	end
	START_ADDRL:
	begin
		if ((bit_cn == 4'b0000)&&(freq_cn == frequency))
		begin
		    fsm_FLASH_ns = I2C_IDLE_AGAIN;
		end
		else
		begin
		    fsm_FLASH_ns = START_ADDRL;
		end
	end
	I2C_IDLE_AGAIN:
	begin
	     fsm_FLASH_ns = I2C_INIT_AGAIN;
	end
	I2C_INIT_AGAIN:
	begin
	    if (jump_en)
	        fsm_FLASH_ns = I2C_START_AGAIN;
	    else
	        fsm_FLASH_ns = I2C_INIT_AGAIN;
	end
	I2C_START_AGAIN:
	begin
	    if (jump_en)
	        fsm_FLASH_ns = ADDR_READY_AGAIN;
	    else
	        fsm_FLASH_ns = I2C_START_AGAIN;    
	end
	ADDR_READY_AGAIN:
	begin
	    fsm_FLASH_ns = FLASH_ADDR;
	end
	FLASH_ADDR:
	begin
		if ((bit_cn == 4'b0000)&&(freq_cn == frequency))
		begin
			fsm_FLASH_ns = RECV_DATAH;
		end
		else 
		begin
			fsm_FLASH_ns = FLASH_ADDR;
		end
	end
	RECV_DATAH:
	begin
		if ((bit_cn == 4'b0001)&&(freq_cn == frequency))
		begin
			 fsm_FLASH_ns = SEND_ACK1;
		end
		else
		begin
		    fsm_FLASH_ns = RECV_DATAH;
		end
	end
	SEND_ACK1:
	begin
	    if (freq_cn == frequency)
	    begin
			fsm_FLASH_ns = RECV_DATAL;
		end
		else
		begin
			fsm_FLASH_ns = SEND_ACK1;
		end
	end	
	RECV_DATAL:
	begin
	    if ((bit_cn == 4'b0001)&&(freq_cn == frequency) && (total_word_cn < `ADDR_SZ'hb00 /*10'h3e8*/))  //Modified by SYF 2014.5.20
	    begin
	        fsm_FLASH_ns = SEND_ACK2;
	    end
	    else if ((bit_cn == 4'b0001) &&(freq_cn == frequency)&& (total_word_cn == `ADDR_SZ'hb00 /*10'h3e8*/))   //Modified by SYF 2014.5.20
	    begin
			fsm_FLASH_ns = READY_STOP;
		end
		else
		begin
			 fsm_FLASH_ns = RECV_DATAL;
		end
	end
	SEND_ACK2:
	begin
	    if (freq_cn == frequency)
	    begin
			fsm_FLASH_ns = RECV_DATAH;
		end
		else
		begin
			fsm_FLASH_ns = SEND_ACK2;
		end
	end	
	READY_STOP:
	begin
	    if (jump_en)
	    begin
	        fsm_FLASH_ns = STOP_SIGNAL;
	    end
	    else
	    begin
	        fsm_FLASH_ns = READY_STOP;
	    end
    end
	STOP_SIGNAL:
	begin
	    if (jump_en)
	    begin
	        fsm_FLASH_ns = READ_DONE;
	    end
	    else
	    begin
	        fsm_FLASH_ns = STOP_SIGNAL;
	    end
    end
	READ_DONE:
	begin
	    if (tbuf == 8'h80)
		 begin
	        fsm_FLASH_ns = IDLE_FLASH;
		 end
		 else
		 begin
		     fsm_FLASH_ns = READ_DONE;
	    end
    end
    endcase
end

always @ (posedge i_clk,negedge i_rst_n)
begin
    if (!i_rst_n)
	 begin
	     tbuf <= 8'h0;
	 end
    else if  (fsm_FLASH_cs == READ_DONE)    
    begin
       tbuf <= tbuf + 8'h1;
    end
    else 
    begin
        tbuf <= 8'h0;
	 end
end

/*bit counter and the last bit is ack*/    
always @ (posedge i_clk,negedge i_rst_n)
begin
	if (!i_rst_n)
    begin
		bit_cn <= 4'b1000;
	end
	else if (fsm_FLASH_ns != fsm_FLASH_cs)
	begin
		bit_cn <= 4'b1000;
	end
	else if (freq_cn == frequency)
	begin
		bit_cn <= bit_cn - 1'b1;
	end
end


always @ (posedge i_clk,negedge i_rst_n)
begin
	if (!i_rst_n)
    begin
		freq_cn <= 8'h0;
	end
	else if ((fsm_FLASH_ns != fsm_FLASH_cs) || (freq_cn == frequency))
	begin
		freq_cn <= 8'h0;
	end
	else if ( (fsm_FLASH_ns == PSEUDO_WRITE)
	          ||(fsm_FLASH_ns == FLASH_ADDR) 
	          || (fsm_FLASH_ns == START_ADDRH)
	          || (fsm_FLASH_ns == START_ADDRL)
	          || (fsm_FLASH_ns == RECV_DATAH)
	          || (fsm_FLASH_ns == RECV_DATAL)  
		      || (fsm_FLASH_ns == SEND_ACK1) 
	          || (fsm_FLASH_ns == SEND_ACK2) 
            )
	begin
		freq_cn <= freq_cn + 1'b1;
	end
end
	

always @ (posedge i_clk,negedge i_rst_n)
begin
	if (!i_rst_n)
    begin
		  scl_en <= 1'b0;
	end
	else if (freq_cn == 8'h80)
	begin
        scl_en <= 1'b1;
    end
    else if (freq_cn == 8'hF0)
    begin
		scl_en <= 1'b0;
	end
end

always @ (posedge i_clk,negedge i_rst_n)
begin
	if (!i_rst_n)
    begin
		o_scl <= 1'b1;
	end
	else if (   (fsm_FLASH_ns == I2C_INIT) 
	         || (fsm_FLASH_ns == I2C_START) 
	         || (fsm_FLASH_ns == I2C_INIT_AGAIN)
	         || (fsm_FLASH_ns == I2C_START_AGAIN)
	         || (fsm_FLASH_ns == STOP_SIGNAL)
	         || (fsm_FLASH_ns == READ_DONE)	
	         || scl_en)
	begin
		o_scl <= 1'b1;
	end
	else 
	begin
		o_scl <= 1'b0;
	end
end

always @ (posedge i_clk,negedge i_rst_n)
begin
	if (!i_rst_n)
    begin
		total_word_cn <= `ADDR_SZ'h0;       //Modified by SYF 2014.5.20
	end
	else if ((fsm_FLASH_ns == RECV_DATAL)&&(bit_cn == 4'b0001)&& o_scl && !scl_dly1)
	begin
		total_word_cn <= total_word_cn + `ADDR_SZ'h1;   //Modified by SYF 2014.5.20
	end
	else if (fsm_FLASH_ns == READ_DONE)
    begin
		total_word_cn <= `ADDR_SZ'h0;       //Modified by SYF 2014.5.20
	end
end	


always @ (posedge i_clk,negedge i_rst_n)
begin
	if (!i_rst_n)
    begin
		sda_recv <= 1'bz;
	end
	else 
	case (fsm_FLASH_ns)
	IDLE_FLASH,RECV_DATAH,RECV_DATAL:
	begin
		sda_recv <= 1'bz;//note 1 to z
	end
    I2C_INIT,I2C_INIT_AGAIN,READ_DONE,I2C_IDLE_AGAIN:
	begin
		sda_recv <= 1'b1;
	end
	I2C_START,FLASH_ADDR_READY,I2C_START_AGAIN,ADDR_READY_AGAIN,SEND_ACK1,SEND_ACK2,READY_STOP,STOP_SIGNAL:		
	begin
		sda_recv <= 1'b0;
	end	
	PSEUDO_WRITE,FLASH_ADDR:
	begin
	    if (bit_cn != 4'h0)
	    begin
			sda_recv <= flash_addr [bit_cn-1];//to ensure the bit count is sync with flash-addr 
		end
		else
		begin
			sda_recv <= 1'bz;
		end
	end
	START_ADDRH:
	begin
	    if (bit_cn != 4'h0)
	    begin
			sda_recv <= start_addrh [bit_cn-1];//to ensure the bit count is sync with flash-addr 
		end
		else
		begin
			sda_recv <= 1'bz;
		end
	end
	START_ADDRL:
	begin
	    if (bit_cn != 4'h0)
	    begin
			sda_recv <= start_addrl [bit_cn-1];//to ensure the bit count is sync with flash-addr 
		end
		else
		begin
			sda_recv <= 1'bz;
		end
	end	
	default:
	begin
		sda_recv <= 1'bz;
	end
	endcase
end

always @ (posedge i_clk,negedge i_rst_n)
begin
	if (!i_rst_n)
    begin
        o_flash_data <= 16'h0;
    end
    else if ((fsm_FLASH_ns == RECV_DATAH)&& o_scl)
    begin
		o_flash_data[bit_cn+7] <= b_sda;
	end
	else if ((fsm_FLASH_ns == RECV_DATAL)&& o_scl)
    begin
		o_flash_data[bit_cn-1] <= b_sda;
	end
end

always @ (posedge i_clk,negedge i_rst_n)
begin
	if (!i_rst_n)
    begin
        o_flash_raddr <= `ADDR_SZ'h0;    //Modified by SYF 2014.5.20
    end
    else if ((fsm_FLASH_ns == RECV_DATAL)&& (bit_cn == 4'b0001)&& o_scl && !scl_dly1)
    begin
		o_flash_raddr <= o_flash_raddr + `ADDR_SZ'h1;    //Modified by SYF 2014.5.20
	end
	else if (fsm_FLASH_ns == READ_DONE)
	begin
		o_flash_raddr <= `ADDR_SZ'h0;     //Modified by SYF 2014.5.20
    end
end

always @ (posedge i_clk,negedge i_rst_n)
begin
	if (!i_rst_n)
    begin
        o_flash_rd_en <= 1'b0;
    end
    else if ((fsm_FLASH_ns == RECV_DATAL)&& (bit_cn == 4'b0001)&& o_scl && !scl_dly1)
    begin
		o_flash_rd_en <= 1'b1;
	end
	else 
	begin
        o_flash_rd_en <= 1'b0;
    end
end

always @ (posedge i_clk,negedge i_rst_n)
begin
	if (!i_rst_n)
    begin
        o_flash_read_done <= 1'b0;
    end
    else if (fsm_FLASH_ns == READ_DONE) 
    begin
		o_flash_read_done <= 1'b1;
    end
    else
    begin
        o_flash_read_done <= 1'b0;
    end
end
endmodule
