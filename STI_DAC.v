module STI_DAC(clk ,reset, load, pi_data, pi_length, pi_fill, pi_msb, pi_low, pi_end,
	       so_data, so_valid,
	       oem_finish, oem_dataout, oem_addr,
	       odd1_wr, odd2_wr, odd3_wr, odd4_wr, even1_wr, even2_wr, even3_wr, even4_wr);

input		clk, reset;
input		load, pi_msb, pi_low, pi_end; 
input	[15:0]	pi_data;
input	[1:0]	pi_length;
input		pi_fill;
output		so_data, so_valid;

output  oem_finish, odd1_wr, odd2_wr, odd3_wr, odd4_wr, even1_wr, even2_wr, even3_wr, even4_wr;
output [4:0] oem_addr;
output [7:0] oem_dataout;

//==============================================================================
//parameter 	RST = 0, LOAD = 1, STI = 2, TEST = 3, ZERO = 4, FINISH = 5 ;
parameter IDLE = 0, LOAD = 1, STI = 2,  STI_END = 3, WAIT = 4, ZERO = 5, FINISH = 6;
parameter ODD = 1'd0, EVEN = 1'd1;
integer i;

reg [6:0] cs,ns;

reg so_valid,so_data;

reg [7:0] oem_dataout;
reg [4:0] oem_addr;
reg oem_finish,
    odd1_wr,odd2_wr,odd3_wr,odd4_wr,
    even1_wr,even2_wr,even3_wr,even4_wr;

reg en;
reg [2:0] cnt8;
reg [1:0] cnt4;
reg en_odd_even;
reg [1:0] cnt_odd_wr,cnt_even_wr;
reg [7:0] odd_even;
reg [2:0] cnt_en;
wire [3:0] A24;
assign A24 = 4'd15 - cnt8 -8*(cnt4 - 2'd1);

always @(posedge clk or posedge reset) begin
	if(reset)begin
        cs <= 'd0;
        cs[IDLE] <= 1'd1;
    end
    else cs <= ns;
end

always @(*) begin
    ns = 'd0;
    if(reset) ns[IDLE] = 1'd1;
    else begin
        case (1'd1)
            cs[IDLE]:                                                           ns[LOAD]    = 1'd1;
            cs[LOAD]:                                                           ns[STI]     = 1'd1;
            cs[STI]:begin                   
                case (pi_length)                    
                    2'b00:begin                 
                        if(cnt8 == 3'd7 && cnt4 == 2'd0)                        ns[STI_END] = 1'd1;
                        else                                                    ns[STI]     = 1'd1;
                    end                 
                    2'b01:begin                 
                        if(cnt8 == 3'd7 && cnt4 == 2'd1)                        ns[STI_END] = 1'd1;
                        else                                                    ns[STI]     = 1'd1;
                    end                 
                    2'b10:begin                 
                        if(cnt8 == 3'd7 && cnt4 == 2'd2)                        ns[STI_END] = 1'd1;
                        else                                                    ns[STI]     = 1'd1;
                    end                 
                    2'b11:begin                 
                        if(cnt8 == 3'd7 && cnt4 == 2'd3)                        ns[STI_END] = 1'd1;
                        else                                                    ns[STI]     = 1'd1;
                    end
                endcase
            end
            cs[STI_END]:                                                        ns[WAIT]    = 1'd1;
            cs[WAIT]:begin
                if((pi_end == 1'd1)&&(oem_addr==5'd0)&&(cnt_even_wr==2'd0))    ns[FINISH] = 1'd1;
                else if(pi_end == 1'd1)                                         ns[ZERO]    = 1'd1;
                else                                                            ns[LOAD]    = 1'd1;
            end
            cs[ZERO]:begin 
                if((oem_addr==5'd31)&&(cnt_even_wr==2'd3)&&(cnt_odd_wr==2'd3))  ns[FINISH]  = 1'd1;
                else                                                            ns[ZERO]    = 1'd1;
            end         
            cs[FINISH]:                                                         ns[FINISH]  = 1'd1;
            default:                                                            ns[IDLE]     = 1'd1;
        endcase
    end
end

//////cnt4 //cnt8 
always @(posedge clk or posedge reset) begin
    if (reset) begin
        cnt4 <= 2'd0;
        cnt8 <= 3'd0;
    end
    else begin
        case (1'd1)
            cs[IDLE]:begin
                cnt4 <= 2'd0;
                cnt8 <= 3'd0;
            end
            cs[LOAD]:;
            cs[STI]:begin
                cnt8 <= cnt8 + 3'd1;
                if(cnt8 == 3'd7)    cnt4 <= cnt4 +2'd1;
                else                cnt4 <= cnt4; 
            end 
            cs[STI_END]:begin
                cnt4 <= 2'd0;
                cnt8 <= 3'd0;
            end
            cs[WAIT]:;
            cs[ZERO]:;
            cs[FINISH]:;
        endcase
    end
end

//////so_valid
always @(posedge clk or posedge reset) begin
    if(reset)begin
        so_valid <= 1'd0;
    end
    else begin
        case (1'd1)
            cs[IDLE]:       so_valid <= 1'd0;
            cs[LOAD]:;
            cs[STI]:        so_valid <= 1'd1;
            cs[STI_END]:    so_valid <= 1'd0;
            cs[WAIT]: ;      
            cs[ZERO]:;
            cs[FINISH]:;
        endcase
    end
end

//////so_data //odd_even
always @(posedge clk or posedge reset) begin
    if(reset)begin
       so_data <= 1'd0;
       odd_even <= 8'd0; 
    end
    else begin
        case (1'd1)
            cs[IDLE]:begin
                so_data <= 1'd0;
                odd_even <= 8'd0; 
            end 
            cs[LOAD]:;
            cs[STI]:begin
                //pi_msb 1大到小 0小到大
		    	//pi_low 8bit 1對其大pi_data[15:8] 0對其小pi_data[7:0]
		    	//pi_fill 24 32bit 1對其大 0對其小 其餘補0
                case (pi_length)
                    //8bit
                    2'b00:begin 
                        case (pi_low)
                            1'd1:begin//pi_data[15:8]
                                if(pi_msb)begin
                                    so_data <= pi_data[4'd15 - cnt8];
                                    odd_even[cnt8] <= pi_data[4'd15 - cnt8];
                                end
                                else begin
                                    so_data <= pi_data[4'd8 + cnt8];
                                    odd_even[cnt8] <= pi_data[4'd8 + cnt8];
                                end
                            end
                            1'd0:begin//pi_data[7:0]
                                if(pi_msb)begin
                                    so_data <= pi_data[4'd7 - cnt8];
                                    odd_even[cnt8] <= pi_data[4'd7 - cnt8];
                                end
                                else begin
                                    so_data <= pi_data[cnt8];
                                    odd_even[cnt8] <= pi_data[cnt8];
                                end
                            end 
                        endcase
                    end

                    //16bit
                    2'b01:begin 
                        if(pi_msb)begin //pi_data[15:0]
                            so_data <= pi_data[4'd15 - cnt8 - 8*cnt4];
                            odd_even[cnt8] <= pi_data[4'd15 - cnt8 - 8*cnt4];
                        end
                        else begin //pi_data[15:0]
                            so_data <= pi_data[cnt8 + 8*cnt4];
                            odd_even[cnt8] <= pi_data[cnt8 + 8*cnt4];
                        end
                    end

                    //24bit
                    2'b10:begin 
                        case (pi_fill)
                            1'd1:begin //pi_data[15:0] 8'd0
                                if(pi_msb)begin
                                    if(cnt4 == 2'd2) begin
                                        so_data <= 1'd0;
                                        odd_even[cnt8] <= 1'd0;
                                    end
                                    else begin
                                        so_data <= pi_data[4'd15 - cnt8 -8*cnt4];
                                        odd_even[cnt8] <= pi_data[4'd15 - cnt8 -8*cnt4];
                                    end
                                end
                                else begin
                                    if(cnt4 == 2'd0) begin
                                        so_data <= 1'd0;
                                        odd_even[cnt8] <= 1'd0;
                                    end
                                    else begin
                                        so_data <= pi_data[cnt8 + 8*(cnt4 - 2'd1)];
                                        odd_even[cnt8] <= pi_data[cnt8 + 8*(cnt4 - 2'd1)];
                                    end
                                end
                            end
                            1'd0:begin //8'd0 pi_data[15:0]
                                if (pi_msb) begin
                                    if((cnt4 == 2'd1)||(cnt4 == 2'd2)||(cnt4 == 2'd3))begin
                                        so_data <= pi_data[A24];
                                        odd_even[cnt8] <= pi_data[A24];//[4'd15 - cnt8 -8*(cnt4 - 2'd1)];
                                        
                                    end
                                    else begin
                                        so_data <= 1'd0;
                                        odd_even[cnt8] <= 1'd0;
                                    end
                                end
                                else begin
                                    if(cnt4 == 2'd2)begin
                                        so_data <= 1'd0;
                                        odd_even[cnt8] <= 1'd0;
                                    end
                                    else begin
                                        so_data <= pi_data[cnt8 + 8*cnt4];
                                        odd_even[cnt8] <= pi_data[cnt8 + 8*cnt4];
                                    end
                                end
                            end 
                        endcase
                    end

                    //32bit
                    2'b11:begin
                        case (pi_fill)
                            1'd1:begin //pi_data[15:0] 16'd0
                                if(pi_msb) begin
                                    if(cnt4 == 2'd2 || cnt4 == 2'd3)begin
                                        so_data <= 1'd0;
                                        odd_even[cnt8] <= 1'd0;
                                    end
                                    else begin
                                        so_data <= pi_data[4'd15 - cnt8 - 8*cnt4];
                                        odd_even[cnt8] <=  pi_data[4'd15 - cnt8 - 8*cnt4];
                                    end
                                end
                                else begin
                                    if(cnt4 == 2'd0 || cnt4 ==2'd1)begin
                                        so_data <= 1'd0;
                                        odd_even[cnt8] <= 1'd0;
                                    end
                                    else begin
                                        so_data <= pi_data[cnt8 + 8*(cnt4 - 2'd2)];
                                        odd_even[cnt8] <= pi_data[cnt8 + 8*(cnt4 - 2'd2)];
                                    end
                                end
                            end
                            1'd0:begin //16'd0 pi_data[15:0]
                                if(pi_msb) begin
                                    if(cnt4 == 2'd0 || cnt4 == 2'd1)begin
                                        so_data <= 1'd0;
                                        odd_even[cnt8] <= 1'd0;
                                    end
                                    else begin
                                        so_data <= pi_data[4'd15 - cnt8 - 8*(cnt4 - 2'd2)];
                                        odd_even[cnt8] <=  pi_data[4'd15 - cnt8 - 8*(cnt4 - 2'd2)];
                                    end
                                end
                                else begin
                                    if(cnt4 == 2'd2 || cnt4 == 2'd3)begin
                                        so_data <= 1'd0;
                                        odd_even[cnt8] <= 1'd0;
                                    end
                                    else begin
                                        so_data <= pi_data[cnt8 + 8*cnt4];
                                        odd_even[cnt8] <= pi_data[cnt8 + 8*cnt4];
                                    end
                                end
                            end 
                        endcase
                    end
                endcase
            end
            cs[STI_END]:;
            cs[WAIT]:;
            cs[ZERO]:;
            cs[FINISH]:;
        endcase
    end
end
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
always@(posedge clk or posedge reset)begin
    if(reset) en <= 1'd0;
    else if ((pi_end==1'd1)&&(oem_addr==3'd31)&&(cnt_even_wr==2'd3)&&(cnt_odd_wr==2'd3)) en <= 1'd1;
    else en <= 1'd0;
end
 
////////////////////////////////////////////////////////////
always@(posedge clk or posedge reset)begin
    if(reset) oem_addr <= 5'd0;
    else if (((cnt_en==3'd1)||(cnt_en==3'd3)||(cnt_en==3'd5)||(cnt_en==3'd7))&&( (odd1_wr==1'd1)||(odd2_wr==1'd1)||(odd3_wr==1'd1)||(odd4_wr==1'd1)||(even1_wr==1'd1)||(even2_wr==1'd1)||(even3_wr==1'd1)||(even4_wr==1'd1) )) oem_addr <= oem_addr + 5'd1;
    else oem_addr <= oem_addr;
end
//////cnt_en
always @(posedge clk or posedge reset) begin
    if(reset) cnt_en <= 3'd0;
    else if( (odd1_wr==1'd1)||(odd2_wr==1'd1)||(odd3_wr==1'd1)||(odd4_wr==1'd1)||(even1_wr==1'd1)||(even2_wr==1'd1)||(even3_wr==1'd1)||(even4_wr==1'd1) ) cnt_en <= cnt_en +1'd1;
    else cnt_en <= cnt_en;
end

//////new en_odd_even
always @(posedge clk or posedge reset) begin
    if(reset) en_odd_even <= ODD;
    else begin
        case (1'd1)
            cs[IDLE]: en_odd_even <= ODD;
            cs[LOAD]:;
            cs[STI]:begin
                if( (cnt8==3'd1 && cnt4==2'd1)||(cnt8==3'd1 && cnt4==2'd2)||(cnt8==3'd1 && cnt4==2'd3) ) begin
                    if(cnt_en == 3'd7) en_odd_even <= en_odd_even;
                    else en_odd_even <= en_odd_even + 1'd1;
                end
            end
            cs[STI_END]:;
            cs[WAIT]:begin
                if(pi_end==1'd1) en_odd_even <= en_odd_even + 1'd1;
                else begin
                    if(cnt_en == 3'd7) en_odd_even <= en_odd_even;
                    else en_odd_even <= en_odd_even + 1'd1;
                end
                 
            end
            cs[ZERO]:begin
                en_odd_even <= en_odd_even + 1'd1;
            end
        endcase
    end
end

//////
always @(posedge clk or posedge reset) begin
    if (reset) begin
        odd1_wr <= 1'd0;
        odd2_wr <= 1'd0;
        odd3_wr <= 1'd0;
        odd4_wr <= 1'd0;
        even1_wr <= 1'd0;
        even2_wr <= 1'd0;
        even3_wr <= 1'd0;
        even4_wr <= 1'd0; 
    end
    else begin
        case (1'd1)
            cs[IDLE]:begin
                odd1_wr <= 1'd0;
                odd2_wr <= 1'd0;
                odd3_wr <= 1'd0;
                odd4_wr <= 1'd0;
                even1_wr <= 1'd0;
                even2_wr <= 1'd0;
                even3_wr <= 1'd0;
                even4_wr <= 1'd0; 
            end
            cs[LOAD]:begin
                odd1_wr <= 1'd0;
                odd2_wr <= 1'd0;
                odd3_wr <= 1'd0;
                odd4_wr <= 1'd0;
                even1_wr <= 1'd0;
                even2_wr <= 1'd0;
                even3_wr <= 1'd0;
                even4_wr <= 1'd0; 
            end
            cs[STI]:begin
                case (en_odd_even)
                    ODD:begin //odd
                        if( (cnt8==3'd1 && cnt4==2'd1)||(cnt8==3'd1 && cnt4==2'd2)||(cnt8==3'd1 && cnt4==2'd3) ) begin 
                            case (cnt_odd_wr)
                                2'd0: odd1_wr <= 1'd1;
                                2'd1: odd2_wr <= 1'd1;
                                2'd2: odd3_wr <= 1'd1;
                                2'd3: odd4_wr <= 1'd1;
                            endcase
                        end
                        else begin
                            odd1_wr <= 1'd0;
                            odd2_wr <= 1'd0;
                            odd3_wr <= 1'd0;
                            odd4_wr <= 1'd0;
                            even1_wr <= 1'd0;
                            even2_wr <= 1'd0;
                            even3_wr <= 1'd0;
                            even4_wr <= 1'd0;
                        end
                    end
                    EVEN:begin //even
                        if( (cnt8==3'd1 && cnt4==2'd1)||(cnt8==3'd1 && cnt4==2'd2)||(cnt8==3'd1 && cnt4==2'd3) ) begin 
                            case (cnt_even_wr)
                                2'd0: even1_wr <= 1'd1;
                                2'd1: even2_wr <= 1'd1;
                                2'd2: even3_wr <= 1'd1;
                                2'd3: even4_wr <= 1'd1;
                            endcase
                        end
                        else begin
                            odd1_wr <= 1'd0;
                            odd2_wr <= 1'd0;
                            odd3_wr <= 1'd0;
                            odd4_wr <= 1'd0;
                            even1_wr <= 1'd0;
                            even2_wr <= 1'd0;
                            even3_wr <= 1'd0;
                            even4_wr <= 1'd0;
                        end
                    end 
                endcase
            end 
            cs[STI_END]:;            
            cs[WAIT]:begin
                case (en_odd_even)
                    ODD:begin 
                        case (cnt_odd_wr)
                            2'd0: odd1_wr <= 1'd1;
                            2'd1: odd2_wr <= 1'd1;
                            2'd2: odd3_wr <= 1'd1;
                            2'd3: odd4_wr <= 1'd1;
                        endcase
                    end
                    EVEN:begin 
                        case (cnt_even_wr)
                            2'd0: even1_wr <= 1'd1;
                            2'd1: even2_wr <= 1'd1;
                            2'd2: even3_wr <= 1'd1;
                            2'd3: even4_wr <= 1'd1;
                        endcase
                    end 
                endcase
            end
            cs[ZERO]:begin
                /*if (en == 1'd1) begin
                    odd1_wr <= 1'd0;
                    odd2_wr <= 1'd0;
                    odd3_wr <= 1'd0;
                    odd4_wr <= 1'd0;
                    even1_wr <= 1'd0;
                    even2_wr <= 1'd0;
                    even3_wr <= 1'd0;
                    even4_wr <= 1'd0;
                end
                else */
                begin
                    case (en_odd_even)
                        ODD:begin 
                            case (cnt_odd_wr)
                                2'd0:begin
                                    odd1_wr <= 1'd1;
                                    odd2_wr <= 1'd0;
                                    odd3_wr <= 1'd0;
                                    odd4_wr <= 1'd0;
                                    even1_wr <= 1'd0;
                                    even2_wr <= 1'd0;
                                    even3_wr <= 1'd0;
                                    even4_wr <= 1'd0;
                                end
                                2'd1:begin
                                    odd1_wr <= 1'd0;
                                    odd2_wr <= 1'd1;
                                    odd3_wr <= 1'd0;
                                    odd4_wr <= 1'd0;
                                    even1_wr <= 1'd0;
                                    even2_wr <= 1'd0;
                                    even3_wr <= 1'd0;
                                    even4_wr <= 1'd0;
                                end
                                2'd2:begin
                                    odd1_wr <= 1'd0;
                                    odd2_wr <= 1'd0;
                                    odd3_wr <= 1'd1;
                                    odd4_wr <= 1'd0;
                                    even1_wr <= 1'd0;
                                    even2_wr <= 1'd0;
                                    even3_wr <= 1'd0;
                                    even4_wr <= 1'd0;
                                end
                                2'd3:begin
                                    odd1_wr <= 1'd0;
                                    odd2_wr <= 1'd0;
                                    odd3_wr <= 1'd0;
                                    odd4_wr <= 1'd1;
                                    even1_wr <= 1'd0;
                                    even2_wr <= 1'd0;
                                    even3_wr <= 1'd0;
                                    even4_wr <= 1'd0;
                                end
                            endcase
                        end 
                        EVEN:begin 
                            case (cnt_even_wr)                        
                                2'd0:begin
                                    odd1_wr <= 1'd0;
                                    odd2_wr <= 1'd0;
                                    odd3_wr <= 1'd0;
                                    odd4_wr <= 1'd0;
                                    even1_wr <= 1'd1;
                                    even2_wr <= 1'd0;
                                    even3_wr <= 1'd0;
                                    even4_wr <= 1'd0;
                                end
                                2'd1:begin
                                    odd1_wr <= 1'd0;
                                    odd2_wr <= 1'd0;
                                    odd3_wr <= 1'd0;
                                    odd4_wr <= 1'd0;
                                    even1_wr <= 1'd0;
                                    even2_wr <= 1'd1;
                                    even3_wr <= 1'd0;
                                    even4_wr <= 1'd0;
                                end
                                2'd2:begin
                                    odd1_wr <= 1'd0;
                                    odd2_wr <= 1'd0;
                                    odd3_wr <= 1'd0;
                                    odd4_wr <= 1'd0;
                                    even1_wr <= 1'd0;
                                    even2_wr <= 1'd0;
                                    even3_wr <= 1'd1;
                                    even4_wr <= 1'd0;
                                end
                                2'd3:begin
                                    odd1_wr <= 1'd0;
                                    odd2_wr <= 1'd0;
                                    odd3_wr <= 1'd0;
                                    odd4_wr <= 1'd0;
                                    even1_wr <= 1'd0;
                                    even2_wr <= 1'd0;
                                    even3_wr <= 1'd0;
                                    even4_wr <= 1'd1;
                                end
                            endcase
                        end 
                    endcase
                end
            end 
            cs[FINISH]:begin
                odd1_wr <= 1'd0;
                odd2_wr <= 1'd0;
                odd3_wr <= 1'd0;
                odd4_wr <= 1'd0;
                even1_wr <= 1'd0;
                even2_wr <= 1'd0;
                even3_wr <= 1'd0;
                even4_wr <= 1'd0; 
            end 
        endcase 
    end 
end

//////oem_dataout //odd_wr //even_wr //oem_finish
always @(posedge clk or posedge reset) begin
    if(reset)begin
        oem_dataout <= 8'd0;
        oem_finish <= 1'd0;  
    end
    else begin
        case (1'd1)
            cs[IDLE]:begin
                oem_dataout <= 8'd0;
                oem_finish <= 1'd0;
            end
            cs[LOAD]:;
            cs[STI]:begin
                case (en_odd_even)
                    ODD:begin //odd
                        if( (cnt8==3'd0 && cnt4==2'd1)||(cnt8==3'd0 && cnt4==2'd2)||(cnt8==3'd0 && cnt4==2'd3) ) begin
                            oem_dataout[7:0] <= {odd_even[0],odd_even[1],odd_even[2],odd_even[3],odd_even[4],odd_even[5],odd_even[6],odd_even[7]};//odd_even[0:7];
                            
                            
                        end
                        else begin
                            oem_dataout <= oem_dataout;
                           
                        end
                    end
                    EVEN:begin //even
                        if( (cnt8==3'd0 && cnt4==2'd1)||(cnt8==3'd0 && cnt4==2'd2)||(cnt8==3'd0 && cnt4==2'd3) ) begin
                            oem_dataout[7:0] <= {odd_even[0],odd_even[1],odd_even[2],odd_even[3],odd_even[4],odd_even[5],odd_even[6],odd_even[7]};//odd_even[0:7];
                            
                           
                        end
                        else begin
                            oem_dataout <= oem_dataout;
                            
                        end
                    end 
                endcase
            end 
            cs[STI_END]:begin
                case (en_odd_even)
                    ODD:begin
                        oem_dataout[7:0] <= {odd_even[0],odd_even[1],odd_even[2],odd_even[3],odd_even[4],odd_even[5],odd_even[6],odd_even[7]};//odd_even[0:7];
                        
                       
                    end
                    EVEN:begin
                        oem_dataout[7:0] <= {odd_even[0],odd_even[1],odd_even[2],odd_even[3],odd_even[4],odd_even[5],odd_even[6],odd_even[7]};//odd_even[0:7];
                        
                        
                    end 
                endcase
            end
            cs[WAIT]:;
            cs[ZERO]:begin
                case (en_odd_even)
                    ODD:begin
                        oem_dataout <= 8'd0;
                    
                    end 
                    EVEN:begin
                        oem_dataout <= 8'd0;
                       
                    end 
                endcase
            end
            cs[FINISH]: begin
                oem_finish <= 1'd1; 
            end 
        endcase
    end
end


/////////////////////
//////oem_addr //cnt_odd_wr //cnt_even_wr //en_odd_even 
always @(posedge clk or posedge reset) begin
    if(reset)begin
        cnt_odd_wr <= 2'd0;
        cnt_even_wr <= 2'd0;
    end
    else begin
        case (1'd1)
            cs[IDLE]:begin
                cnt_odd_wr <= 2'd0;
                cnt_even_wr <= 2'd0;
            end
            cs[LOAD]:;
            cs[STI]:begin
                case (en_odd_even)
                    ODD:begin //odd
                        if( (cnt8==3'd1 && cnt4==2'd1)||(cnt8==3'd1 && cnt4==2'd2)||(cnt8==3'd1 && cnt4==2'd3) ) begin
                          
                            if(oem_addr == 5'd31) cnt_odd_wr <= cnt_odd_wr+2'd1;
                            else cnt_odd_wr <= cnt_odd_wr;
                        end
                        else begin
                           
                            cnt_odd_wr <= cnt_odd_wr;
                        end
                    end
                    EVEN:begin //even
                        if( (cnt8==3'd1 && cnt4==2'd1)||(cnt8==3'd1 && cnt4==2'd2)||(cnt8==3'd1 && cnt4==2'd3) ) begin
                            
                            if(oem_addr == 5'd31) cnt_even_wr <= cnt_even_wr+2'd1;
                            else cnt_even_wr <= cnt_even_wr;                                             
                        end
                        else begin
                          
                            cnt_even_wr <= cnt_even_wr;
                        end
                    end 
                endcase
            end 
            cs[STI_END]:;
            cs[WAIT]:begin
                case (en_odd_even)
                    ODD:begin
                       
                        if(oem_addr == 5'd31) cnt_odd_wr <= cnt_odd_wr+2'd1;
                        else cnt_odd_wr <= cnt_odd_wr;
                    end 
                    EVEN:begin
                      
                        if(oem_addr == 5'd31) cnt_even_wr <= cnt_even_wr+2'd1;
                        else cnt_even_wr <= cnt_even_wr;
                    end 
                endcase
            end
            cs[ZERO]:begin
                case (en_odd_even)
                    ODD:begin
                   
                        if(oem_addr == 5'd31) cnt_even_wr <= cnt_even_wr+2'd1;
                        else cnt_even_wr <= cnt_even_wr;
                    end
                    EVEN:begin
                        if(oem_addr == 5'd31) cnt_odd_wr <= cnt_odd_wr+2'd1;
                        else cnt_odd_wr <= cnt_odd_wr;
                
                        
                    end 
                endcase
            end
            cs[FINISH]:;
        endcase
    end
end
endmodule
