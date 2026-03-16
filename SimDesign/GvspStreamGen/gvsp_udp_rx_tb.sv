`timescale 1ns/1ps

module gvsp_udp_rx_tb;

    //-------------------------------------------------------------------------
    // 参数设置 (请根据你的实际TXT文件大小修改这些长度)
    //图像宽高是200*200，将首包、有效数据包和尾包求和，得MEM_DEPTH深度
    //-------------------------------------------------------------------------
    parameter CLK1_PERIOD    = 8;             // 125MHz
    parameter CLK2_PERIOD    = 5;             // 200MHz
    // parameter PIC_WIDTH      = 200;           // 图像宽度
    // parameter PIC_HEIGHT     = 200;           // 图像高度
    parameter PIC_WIDTH      = 32;           // 图像宽度
    parameter PIC_HEIGHT     = 32;           // 图像高度
    parameter GVSP_TEST_FILE_NAME   = "../testbench/gvsp_data.txt";     //gvsp输入数据文件路径
    parameter IMG_DECODE_FILE_NAME1 = "../testbench/gray_data1.txt";  //gvsp解码后数据文件路径
    parameter IMG_DECODE_FILE_NAME2 = "../testbench/gray_data2.txt";  //gvsp解码后数据文件路径
    parameter IMG_DECODE_FILT_FILE_NAME1 = "../testbench/filt_gray_data1.txt";  //gvsp解码后数据文件路径
    parameter IMG_DECODE_FILT_FILE_NAME2 = "../testbench/filt_gray_data2.txt";  //gvsp解码后数据文件路径
    parameter IMG_DECODE_PYR_FILE_NAME1 = "../testbench/pyr_gray_data1.txt";  //gvsp解码后数据文件路径
    parameter IMG_DECODE_PYR_FILE_NAME2 = "../testbench/pyr_gray_data2.txt";  //gvsp解码后数据文件路径

    // **关键参数：你需要根据实际包长修改这里**
    // UDP Payload 长度 = GVSP Header (8B) + Data
    // parameter LEN_LEADER    = 44;            // Leader包总长度
    // parameter LEN_PAYLOAD   = 1472;           // 360字节数据 + 8字节GVSP头
    // parameter LEN_PAYLOAD_LAST   = 480;      // 360字节数据 + 8字节GVSP头
    // parameter LEN_TRAILER   = 18;            // Trailer包总长度
    // parameter PAYLOAD_CNT   = 27;            // 有效数据包个数,不包含最后一个不满包
    // parameter GAP_CYCLES    = 20;            // 包间隔周期数
    parameter LEN_LEADER    = 44;            // Leader包总长度
    parameter LEN_PAYLOAD   = 192;           // 360字节数据 + 8字节GVSP头
    parameter LEN_PAYLOAD_LAST   = 112;      // 360字节数据 + 8字节GVSP头
    parameter LEN_TRAILER   = 18;            // Trailer包总长度
    parameter PAYLOAD_CNT   = 5;            // 有效数据包个数,不包含最后一个不满包
    parameter GAP_CYCLES    = 20;            // 包间隔周期数

    parameter MEM_DEPTH      = (LEN_LEADER+(LEN_PAYLOAD*PAYLOAD_CNT)+LEN_PAYLOAD_LAST+LEN_TRAILER+1000);         // txt文件最大字节数

    reg       clk; //125M 
    reg       rst; //复位信号
    reg       axi_clk;
    reg       axi_rstn;
    reg [7:0] mem [0:MEM_DEPTH-1];

    /*
     * udp frame reg
     */
    reg          s_udp_hdr_valid;
    wire         s_udp_hdr_ready;
    //********新增
    reg   [15:0] s_udp_length;    //gvsp_length=s_udp_length-8/20(EI=1; 8; EI=0; 20)
    //************
    reg   [7:0]  s_udp_payload_axis_tdata;
    reg          s_udp_payload_axis_tvalid;
    wire         s_udp_payload_axis_tready;
    reg          s_udp_payload_axis_tlast;
    reg          endpack_flag;
    /*
     * GVSP frame wire
     */
    wire         m_gvsp_hdr_valid;
    wire  [15:0] m_ip_length;
    wire  [15:0] m_udp_source_port;
    wire  [15:0] m_udp_dest_port;
    wire  [15:0] m_udp_length;
    wire  [15:0] m_udp_checksum;

    wire  [7:0]  m_gvsp_payload_axis_tdata;
    wire         m_gvsp_payload_axis_tvalid;
    wire         m_gvsp_payload_axis_tlast;
    wire         m_gvsp_payload_axis_tuser;
    wire         m_gvsp_payload_axis_tready;

    wire                                video_bcam_fval            ;    //测试专用
    wire                                video_bcam_lval            ;
    wire                                video_bcam_dval            ;
    wire               [  7:  0]        video_bcam_gray            ;
    wire               [  15: 0]        pix_filt                   ;
    wire                                filt_fval                  ;
    wire                                filt_lval                  ;
    wire                                filt_dval                  ;
    wire               [  15: 0]        pix_pyrgrid                ;
    wire                                pyrgrid_fval               ;
    wire                                pyrgrid_lval               ;
    wire                                pyrgrid_dval               ;
    wire               [  15: 0]        pix_block                  ;
    wire                                block_fval                 ;
    wire                                block_lval                 ;
    wire                                block_dval                 ;

    integer gray_data1,      gray_data2;       // 文件句柄
    integer filt_gray_data1, filt_gray_data2;  // 文件句柄
    integer pyr_gray_data1,  pyr_gray_data2;   // 文件句柄

    always #4 clk       = ~clk;
    always #2.5 axi_clk = ~axi_clk;
    assign axi_rstn     = ~rst;

    initial begin
        rst                       = 1;
        clk                       = 0;
        axi_clk                   = 0;
        s_udp_payload_axis_tlast  = 0;
        s_udp_payload_axis_tdata  = 0;
        s_udp_payload_axis_tvalid = 0;
        s_udp_length              = 0;
        s_udp_hdr_valid           = 0;
        gray_data1                = $fopen(IMG_DECODE_FILE_NAME1, "w");
        gray_data2                = $fopen(IMG_DECODE_FILE_NAME2, "w");
        filt_gray_data1           = $fopen(IMG_DECODE_FILT_FILE_NAME1, "w");
        filt_gray_data2           = $fopen(IMG_DECODE_FILT_FILE_NAME2, "w");
        pyr_gray_data1            = $fopen(IMG_DECODE_PYR_FILE_NAME1, "w");
        pyr_gray_data2            = $fopen(IMG_DECODE_PYR_FILE_NAME2, "w");
        for (integer i=0;i<MEM_DEPTH;i=i+1) begin
            mem[i] = 0;
        end
        #4000;
        rst = 0;
        #4000;
        $readmemh(GVSP_TEST_FILE_NAME, mem);
        repeat(1) begin
            //*********************首包
            repeat(10) @(posedge clk);
            #2;
            s_udp_length = LEN_LEADER+8;                        //要传输的数据包长度
            s_udp_hdr_valid = 1;
            @ (posedge clk) begin
                if (s_udp_hdr_ready)    s_udp_hdr_valid=0;
                else;
            end
            for (integer i = 0; i < LEN_LEADER; i = i+1) begin
                repeat(1) @(posedge clk);
                #2;
                s_udp_payload_axis_tdata = mem[i];              //当前数据包起始位置在mem中的基地址，每个类型包基地址不同
                s_udp_payload_axis_tvalid = 1;
                if(i==(LEN_LEADER-1)) begin
                    s_udp_payload_axis_tlast = 1;                 
                end else begin
                    s_udp_payload_axis_tlast = 0;     
                end
            end

            repeat(1) @(posedge clk);
            #2;
            s_udp_payload_axis_tlast = 0;            
            s_udp_payload_axis_tdata = 0;
            s_udp_payload_axis_tvalid = 0;
            s_udp_length = 0;
            s_udp_hdr_valid = 0;

            //*********************数据包
            repeat(100) @(posedge clk);
            #2;
            for (integer j = 0; j < PAYLOAD_CNT; j = j+1) begin     //多个数据包循环发送，除尾包外的有效数据包个数
                s_udp_length = LEN_PAYLOAD+8;                   
                s_udp_hdr_valid = 1;
                @ (posedge clk) begin
                    #2;
                    if (s_udp_hdr_ready)    s_udp_hdr_valid=0;
                    else;
                end
                for (integer i = 0; i < LEN_PAYLOAD; i = i+1) begin
                    repeat(1) @(posedge clk);
                    #2;
                    s_udp_payload_axis_tdata = mem[i+LEN_LEADER+(j*LEN_PAYLOAD)];
                    s_udp_payload_axis_tvalid = 1;
                    if(i==(LEN_PAYLOAD-1)) begin
                        s_udp_payload_axis_tlast = 1;              
                    end else begin
                        s_udp_payload_axis_tlast = 0;              
                    end    
                end

                repeat(1) @(posedge clk);
                #2;
                s_udp_payload_axis_tlast = 0;            
                s_udp_payload_axis_tdata = 0;
                s_udp_payload_axis_tvalid = 0;
                s_udp_length = 0;
                s_udp_hdr_valid = 0;

                repeat(100) @(posedge clk);
                #2;
            end

            //最后一个数据包，少发10个数据测试
            s_udp_length = LEN_PAYLOAD_LAST+8;
            s_udp_hdr_valid = 1;
            @ (posedge clk) begin
                if (s_udp_hdr_ready)    s_udp_hdr_valid=0;
                else;
            end
            for (integer i = 0; i < LEN_PAYLOAD_LAST-10; i = i+1) begin    //尾包长度
                repeat(1) @(posedge clk);
                #2;
                s_udp_payload_axis_tdata = mem[i+(LEN_LEADER+LEN_PAYLOAD*PAYLOAD_CNT)];
                s_udp_payload_axis_tvalid = 1;
                if(i==(LEN_PAYLOAD_LAST-11)) begin
                    s_udp_payload_axis_tlast = 1;                 
                end else begin
                    s_udp_payload_axis_tlast = 0; 
                end    
            end

            repeat(1) @(posedge clk);
            #2;
            s_udp_payload_axis_tlast = 0;            
            s_udp_payload_axis_tdata = 0;
            s_udp_payload_axis_tvalid = 0;
            s_udp_length = 0;
            s_udp_hdr_valid = 0;

            repeat(100) @(posedge clk); 
            #2;       

            //*******************尾包

            s_udp_length = 18+8;
            s_udp_hdr_valid = 1;
            @ (posedge clk) begin
                if (s_udp_hdr_ready)    s_udp_hdr_valid=0;
                else;
            end

            for (integer i = 0; i < LEN_TRAILER; i = i+1) begin
                repeat(1) @(posedge clk);
                #2;
                s_udp_payload_axis_tdata = mem[i+(LEN_LEADER+LEN_PAYLOAD*PAYLOAD_CNT+LEN_PAYLOAD_LAST)];
                s_udp_payload_axis_tvalid = 1;
                if(i==(LEN_TRAILER-1)) begin
                    s_udp_payload_axis_tlast = 1; 
                    endpack_flag = 1;                
                end else begin
                    s_udp_payload_axis_tlast = 0;  
                    endpack_flag = 0;
                end
            end   
                    
            repeat(1) @(posedge clk);
            #2;
            s_udp_payload_axis_tlast = 0;            
            s_udp_payload_axis_tdata = 0;
            s_udp_payload_axis_tvalid = 0;
            s_udp_length = 0;
            s_udp_hdr_valid = 0;
            repeat(1000) @(posedge clk);  
            #2;
            #1000;
        end
      
        //错误包测试
        repeat(1) begin
            //*********************首包
            repeat(10) @(posedge clk);
            #2;
            s_udp_length = LEN_LEADER+8;                        //要传输的数据包长度
            s_udp_hdr_valid = 1;
            @ (posedge clk) begin
                if (s_udp_hdr_ready)    s_udp_hdr_valid=0;
                else;
            end
            for (integer i = 0; i < LEN_LEADER; i = i+1) begin
                repeat(1) @(posedge clk);
                #2;
                s_udp_payload_axis_tdata = mem[i];              //当前数据包起始位置在mem中的基地址，每个类型包基地址不同
                s_udp_payload_axis_tvalid = 1;
                if(i==(LEN_LEADER-1)) begin
                    s_udp_payload_axis_tlast = 1;                 
                end else begin
                    s_udp_payload_axis_tlast = 0;     
                end
            end

            repeat(1) @(posedge clk);
            #2;
            s_udp_payload_axis_tlast = 0;            
            s_udp_payload_axis_tdata = 0;
            s_udp_payload_axis_tvalid = 0;
            s_udp_length = 0;
            s_udp_hdr_valid = 0;

            //*********************数据包
            repeat(100) @(posedge clk);
            #2;
            for (integer j = 0; j < PAYLOAD_CNT-2; j = j+1) begin     //多个数据包循环发送，除尾包外的有效数据包个数
                s_udp_length = LEN_PAYLOAD+8;                   
                s_udp_hdr_valid = 1;
                @ (posedge clk) begin
                    #2;
                    if (s_udp_hdr_ready)    s_udp_hdr_valid=0;
                    else;
                end
                for (integer i = 0; i < LEN_PAYLOAD; i = i+1) begin
                    repeat(1) @(posedge clk);
                    #2;
                    s_udp_payload_axis_tdata = mem[i+LEN_LEADER+(j*LEN_PAYLOAD)];
                    s_udp_payload_axis_tvalid = 1;
                    if(i==(LEN_PAYLOAD-1)) begin
                        s_udp_payload_axis_tlast = 1;              
                    end else begin
                        s_udp_payload_axis_tlast = 0;              
                    end    
                end

                repeat(1) @(posedge clk);
                #2;
                s_udp_payload_axis_tlast = 0;            
                s_udp_payload_axis_tdata = 0;
                s_udp_payload_axis_tvalid = 0;
                s_udp_length = 0;
                s_udp_hdr_valid = 0;

                repeat(100) @(posedge clk);
                #2;
            end
            #1000;
        end

        repeat(2) begin
            //*********************首包
            repeat(10) @(posedge clk);
            #2;
            s_udp_length = LEN_LEADER+8;                        //要传输的数据包长度
            s_udp_hdr_valid = 1;
            @ (posedge clk) begin
                if (s_udp_hdr_ready)    s_udp_hdr_valid=0;
                else;
            end
            for (integer i = 0; i < LEN_LEADER; i = i+1) begin
                repeat(1) @(posedge clk);
                #2;
                s_udp_payload_axis_tdata = mem[i];              //当前数据包起始位置在mem中的基地址，每个类型包基地址不同
                s_udp_payload_axis_tvalid = 1;
                if(i==(LEN_LEADER-1)) begin
                    s_udp_payload_axis_tlast = 1;                 
                end else begin
                    s_udp_payload_axis_tlast = 0;     
                end
            end

            repeat(1) @(posedge clk);
            #2;
            s_udp_payload_axis_tlast = 0;            
            s_udp_payload_axis_tdata = 0;
            s_udp_payload_axis_tvalid = 0;
            s_udp_length = 0;
            s_udp_hdr_valid = 0;

            //*******************马上收到尾包
            repeat(1000) @(posedge clk);
            #2;
            s_udp_length = 18+8;
            s_udp_hdr_valid = 1;
            @ (posedge clk) begin
                if (s_udp_hdr_ready)    s_udp_hdr_valid=0;
                else;
            end

            for (integer i = (LEN_LEADER+LEN_PAYLOAD*PAYLOAD_CNT+LEN_PAYLOAD_LAST); i < MEM_DEPTH; i = i+1) begin
                repeat(1) @(posedge clk);
                #2;
                s_udp_payload_axis_tdata = mem[i];
                s_udp_payload_axis_tvalid = 1;
                if(i==(MEM_DEPTH-1)) begin
                    s_udp_payload_axis_tlast = 1; 
                    endpack_flag = 1;                
                end else begin
                    s_udp_payload_axis_tlast = 0;  
                    endpack_flag = 0;
                end
            end   
                    
            repeat(1) @(posedge clk);
            #2;
            s_udp_payload_axis_tlast = 0;            
            s_udp_payload_axis_tdata = 0;
            s_udp_payload_axis_tvalid = 0;
            s_udp_length = 0;
            s_udp_hdr_valid = 0;
            repeat(1000) @(posedge clk);  
            #2;

            //*********************重复发首包
            repeat(1000) @(posedge clk);
            #2;
            s_udp_length = LEN_LEADER+8;                        //要传输的数据包长度
            s_udp_hdr_valid = 1;
            @ (posedge clk) begin
                if (s_udp_hdr_ready)    s_udp_hdr_valid=0;
                else;
            end
            for (integer i = 0; i < LEN_LEADER; i = i+1) begin
                repeat(1) @(posedge clk);
                #2;
                s_udp_payload_axis_tdata = mem[i];              //当前数据包起始位置在mem中的基地址，每个类型包基地址不同
                s_udp_payload_axis_tvalid = 1;
                if(i==(LEN_LEADER-1)) begin
                    s_udp_payload_axis_tlast = 1;                 
                end else begin
                    s_udp_payload_axis_tlast = 0;     
                end
            end

            repeat(1) @(posedge clk);
            #2;
            s_udp_payload_axis_tlast = 0;            
            s_udp_payload_axis_tdata = 0;
            s_udp_payload_axis_tvalid = 0;
            s_udp_length = 0;
            s_udp_hdr_valid = 0;

            //*********************数据包
            repeat(100) @(posedge clk);
            #2;
            for (integer j = 0; j < PAYLOAD_CNT; j = j+1) begin     //多个数据包循环发送，除尾包外的有效数据包个数
                s_udp_length = LEN_PAYLOAD+8;                   
                s_udp_hdr_valid = 1;
                @ (posedge clk) begin
                    #2;
                    if (s_udp_hdr_ready)    s_udp_hdr_valid=0;
                    else;
                end
                for (integer i = 0; i < LEN_PAYLOAD; i = i+1) begin
                    repeat(1) @(posedge clk);
                    #2;
                    s_udp_payload_axis_tdata = mem[i+LEN_LEADER+(j*LEN_PAYLOAD)];
                    s_udp_payload_axis_tvalid = 1;
                    if(i==(LEN_PAYLOAD-1)) begin
                        s_udp_payload_axis_tlast = 1;              
                    end else begin
                        s_udp_payload_axis_tlast = 0;              
                    end    
                end

                repeat(1) @(posedge clk);
                #2;
                s_udp_payload_axis_tlast = 0;            
                s_udp_payload_axis_tdata = 0;
                s_udp_payload_axis_tvalid = 0;
                s_udp_length = 0;
                s_udp_hdr_valid = 0;

                repeat(100) @(posedge clk);
                #2;
            end

            //最后一个数据包
            s_udp_length = LEN_PAYLOAD_LAST+8;
            s_udp_hdr_valid = 1;
            @ (posedge clk) begin
                if (s_udp_hdr_ready)    s_udp_hdr_valid=0;
                else;
            end
            for (integer i = 0; i < LEN_PAYLOAD_LAST; i = i+1) begin    //尾包长度
                repeat(1) @(posedge clk);
                #2;
                s_udp_payload_axis_tdata = mem[i+(LEN_LEADER+LEN_PAYLOAD*PAYLOAD_CNT)];
                s_udp_payload_axis_tvalid = 1;
                if(i==(LEN_PAYLOAD_LAST-1)) begin
                    s_udp_payload_axis_tlast = 1;                 
                end else begin
                    s_udp_payload_axis_tlast = 0; 
                end    
            end

            repeat(1) @(posedge clk);
            #2;
            s_udp_payload_axis_tlast = 0;            
            s_udp_payload_axis_tdata = 0;
            s_udp_payload_axis_tvalid = 0;
            s_udp_length = 0;
            s_udp_hdr_valid = 0;

            repeat(100) @(posedge clk); 
            #2;       

            //*******************尾包

            s_udp_length = 18+8;
            s_udp_hdr_valid = 1;
            @ (posedge clk) begin
                if (s_udp_hdr_ready)    s_udp_hdr_valid=0;
                else;
            end

            for (integer i = (LEN_LEADER+LEN_PAYLOAD*PAYLOAD_CNT+LEN_PAYLOAD_LAST); i < MEM_DEPTH; i = i+1) begin
                repeat(1) @(posedge clk);
                #2;
                s_udp_payload_axis_tdata = mem[i];
                s_udp_payload_axis_tvalid = 1;
                if(i==(MEM_DEPTH-1)) begin
                    s_udp_payload_axis_tlast = 1; 
                    endpack_flag = 1;                
                end else begin
                    s_udp_payload_axis_tlast = 0;  
                    endpack_flag = 0;
                end
            end   
                    
            repeat(1) @(posedge clk);
            #2;
            s_udp_payload_axis_tlast = 0;            
            s_udp_payload_axis_tdata = 0;
            s_udp_payload_axis_tvalid = 0;
            s_udp_length = 0;
            s_udp_hdr_valid = 0;
            repeat(1000) @(posedge clk);  
            #2;
        end
        $fclose(gray_data1);
        $fclose(gray_data2);
        $fclose(filt_gray_data1);
        $fclose(filt_gray_data2);
        $fclose(pyr_gray_data1 );
        $fclose(pyr_gray_data2 );
        #10000;
        $stop;
    end

integer cnt_fvalf, cnt_fvalf_filt, cnt_fvalf_pyr;          // 帧计数器

// 帧计数器：在fval下降沿计数（帧结束时）
initial begin
    cnt_fvalf = 0;
    cnt_fvalf_filt = 0;
    cnt_fvalf_pyr = 0;
    forever begin
        @(negedge video_bcam_fval);  // 等待帧结束
        cnt_fvalf = cnt_fvalf + 1;

        @(negedge filt_fval);  // 等待帧结束
        cnt_fvalf_filt = cnt_fvalf_filt + 1;

        @(negedge pyrgrid_fval);  // 等待帧结束
        cnt_fvalf_pyr = cnt_fvalf_pyr + 1;                
    end
end

//gray
always @(negedge axi_clk) begin
    if (cnt_fvalf == 2 && video_bcam_dval) begin
        $fwrite(gray_data1, "%h ", video_bcam_gray);
    end
end

always @(negedge axi_clk) begin
    if (cnt_fvalf == 3 && video_bcam_dval) begin
        $fwrite(gray_data2, "%h ", video_bcam_gray);
    end
end

//filt
always @(negedge axi_clk) begin
    if (cnt_fvalf_filt == 2 && filt_dval) begin
        $fwrite(filt_gray_data1, "%h ", pix_filt);
    end
end

always @(negedge axi_clk) begin
    if (cnt_fvalf_filt == 3 && filt_dval) begin
        $fwrite(filt_gray_data2, "%h ", pix_filt);
    end
end

//pyr
always @(negedge axi_clk) begin
    if (cnt_fvalf_pyr == 2 && pyrgrid_dval) begin
        $fwrite(pyr_gray_data1, "%h ", pix_pyrgrid);
    end
end

always @(negedge axi_clk) begin
    if (cnt_fvalf_pyr == 3 && pyrgrid_dval) begin
        $fwrite(pyr_gray_data2, "%h ", pix_pyrgrid);
    end
end

gvsp_udp_rx
uut (
    .clk(clk),
    .rst(rst),
    .gvsp_data_pck_num(PAYLOAD_CNT+1),
    /*
     * udp frame reg
     */
    .s_udp_hdr_valid(s_udp_hdr_valid),
    .s_udp_hdr_ready(s_udp_hdr_ready),
    //********新增
    .s_udp_source_port(16'd3957),
    .s_udp_dest_port(0),
    .s_udp_length(s_udp_length),    //gvsp_length=s_udp_length-8/20(EI=1, 8; EI=0, 20)
    .s_udp_checksum(0),
    //************
    .s_udp_payload_axis_tdata(s_udp_payload_axis_tdata),
    .s_udp_payload_axis_tvalid(s_udp_payload_axis_tvalid),
    .s_udp_payload_axis_tready(s_udp_payload_axis_tready),
    .s_udp_payload_axis_tlast(s_udp_payload_axis_tlast),
    .s_udp_payload_axis_tuser(0),

    /*
     * GVSP frame wire
     */
    .m_gvsp_payload_axis_tdata(m_gvsp_payload_axis_tdata),
    .m_gvsp_payload_axis_tvalid(m_gvsp_payload_axis_tvalid),
    .m_gvsp_payload_axis_tready(1'b1),
    .m_gvsp_payload_axis_tlast(m_gvsp_payload_axis_tlast),
    .m_gvsp_payload_axis_tuser(m_gvsp_payload_axis_tuser)
);

    task leader();
        send_payload(LEN_LEADER, 0);
    endtask

    task payload(
        input integer n
    );
        send_payload(LEN_PAYLOAD, LEN_LEADER+(n*LEN_PAYLOAD));
    endtask

    task last_payload();
        send_payload(LEN_PAYLOAD_LAST, (LEN_LEADER+LEN_PAYLOAD*PAYLOAD_CNT));
    endtask

    task trailer();
        send_payload(LEN_TRAILER, (LEN_LEADER+LEN_PAYLOAD*PAYLOAD_CNT+LEN_PAYLOAD_LAST));
    endtask 

    task send_payload(
        input integer LENGTH,
        input integer CUR_POSITION
    );
        // 设置UDP头部
        s_udp_length = LENGTH + 8;
        s_udp_hdr_valid = 1;
        
        // 等待头部就绪
        @(posedge clk);
        if (s_udp_hdr_ready) begin
            s_udp_hdr_valid = 0;
        end
        
        // 发送尾包数据
        for (int i = 0; i < LENGTH; i++) begin
            @(posedge clk);
            #2;
            s_udp_payload_axis_tdata = mem[i + CUR_POSITION];
            s_udp_payload_axis_tvalid = 1'b1;
            s_udp_payload_axis_tlast = (i == (LENGTH - 1)) ? 1'b1 : 1'b0;
        end
        
        // 清理信号
        @(posedge clk);
        #2;
        s_udp_payload_axis_tlast = 0;
        s_udp_payload_axis_tdata = 0;
        s_udp_payload_axis_tvalid = 0;
        s_udp_length = 0;
        s_udp_hdr_valid = 0;
        
        // 等待100个时钟周期
        repeat(100) @(posedge clk);
        #2;
    endtask

endmodule
