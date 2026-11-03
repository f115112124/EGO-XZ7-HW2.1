`timescale 1ns/1ps

// Reuse test: dut_ip is generated from the packaged IP's catalog entry.
// The device is Xilinx AXI GPIO based; vendor GPIO v2.0 ignores WSTRB.
module tb_hw2_gpio;
  reg clk=0;
  always #10 clk=~clk; // 50 MHz, matching the final AXI clock.
  reg resetn=0;
  reg [4:0] buttons=0;
  wire [7:0] leds;
  wire irq;
  reg [16:0] awaddr=0;
  reg [2:0] awprot=0;
  reg awvalid=0;
  wire awready;
  reg [31:0] wdata=0;
  reg [3:0] wstrb=4'hf;
  reg wvalid=0;
  wire wready;
  wire [1:0] bresp;
  wire bvalid;
  reg bready=0;
  reg [16:0] araddr=0;
  reg [2:0] arprot=0;
  reg arvalid=0;
  wire arready;
  wire [31:0] rdata;
  wire [1:0] rresp;
  wire rvalid;
  reg rready=0;
  reg test_done=0;
  reg test_failed=0;
  integer assertions_passed=0;

  dut_ip dut (
    .S_AXI_araddr(araddr), .S_AXI_arprot(arprot),
    .S_AXI_arready(arready), .S_AXI_arvalid(arvalid),
    .S_AXI_awaddr(awaddr), .S_AXI_awprot(awprot),
    .S_AXI_awready(awready), .S_AXI_awvalid(awvalid),
    .S_AXI_bready(bready), .S_AXI_bresp(bresp), .S_AXI_bvalid(bvalid),
    .S_AXI_rdata(rdata), .S_AXI_rready(rready), .S_AXI_rresp(rresp),
    .S_AXI_rvalid(rvalid), .S_AXI_wdata(wdata), .S_AXI_wready(wready),
    .S_AXI_wstrb(wstrb), .S_AXI_wvalid(wvalid),
    .btn_i(buttons), .led_o(leds), .irq(irq),
    .s_axi_aclk(clk), .s_axi_aresetn(resetn)
  );

  localparam [31:0] LED_DATA=32'h00000000;
  localparam [31:0] LED_TRI=32'h00000004;
  localparam [31:0] BTN_DATA=32'h00010000;
  localparam [31:0] BTN_GIER=32'h0001011c;
  localparam [31:0] BTN_IPISR=32'h00010120;
  localparam [31:0] BTN_IPIER=32'h00010128;

  task automatic check(input bit ok,input string label_text);
    begin
      if(!ok) begin
        test_failed=1;
        $error("CHECK_FAILED: %s",label_text);
        $fatal(1,"GPIO_IP_SIM_FAILED");
      end
      assertions_passed=assertions_passed+1;
      $display("CHECK_PASS: %s",label_text);
    end
  endtask

  task automatic axi_write(input [31:0] address,input [31:0] value,
                           input [3:0] strobes,input integer aw_delay,input integer w_delay);
    integer bc;
    begin
      bready=0;
      fork
        begin : aw_channel
          integer c;
          repeat(aw_delay) @(posedge clk);
          @(negedge clk);awaddr=address[16:0];awvalid=1;
          c=0;
          do begin
            @(posedge clk);c=c+1;
            if(c>500) begin test_failed=1;$fatal(1,"AW timeout at %h",address);end
          end while(!awready);
          @(negedge clk);awvalid=0;
        end
        begin : w_channel
          integer c;
          repeat(w_delay) @(posedge clk);
          @(negedge clk);wdata=value;wstrb=strobes;wvalid=1;
          c=0;
          do begin
            @(posedge clk);c=c+1;
            if(c>500) begin test_failed=1;$fatal(1,"W timeout at %h",address);end
          end while(!wready);
          @(negedge clk);wvalid=0;
        end
      join
      bc=0;
      while(!bvalid) begin
        @(posedge clk);bc=bc+1;
        if(bc>500) begin test_failed=1;$fatal(1,"B timeout at %h",address);end
      end
      check(bresp===2'b00,$sformatf("AXI write OKAY at %h",address));
      repeat(3) begin
        @(posedge clk);
        check(bvalid===1'b1 && bresp===2'b00,"B response stable under backpressure");
      end
      @(negedge clk);bready=1;
      @(posedge clk);
      @(negedge clk);bready=0;
    end
  endtask

  task automatic axi_read(input [31:0] address,output [31:0] value);
    integer c;
    begin
      @(negedge clk);araddr=address[16:0];arvalid=1;rready=0;
      c=0;
      do begin
        @(posedge clk);c=c+1;
        if(c>500) begin test_failed=1;$fatal(1,"AR timeout at %h",address);end
      end while(!arready);
      @(negedge clk);arvalid=0;
      c=0;
      while(!rvalid) begin
        @(posedge clk);c=c+1;
        if(c>500) begin test_failed=1;$fatal(1,"R timeout at %h",address);end
      end
      value=rdata;
      check(rresp===2'b00,$sformatf("AXI read OKAY at %h",address));
      repeat(3) begin
        @(posedge clk);
        check(rvalid===1'b1 && rresp===2'b00 && rdata===value,
              "R response stable under backpressure");
      end
      @(negedge clk);rready=1;
      @(posedge clk);
      @(negedge clk);rready=0;
    end
  endtask

  task automatic clear_pending;
    reg [31:0] pending;
    begin
      axi_read(BTN_IPISR,pending);
      axi_write(BTN_IPISR,pending & 1,4'hf,0,0);
    end
  endtask

  reg [31:0] value;
  initial begin
    repeat(20) @(posedge clk);
    @(negedge clk);resetn=1;
    repeat(30) @(posedge clk);
    check(leds===8'h00,"LED reset value is zero");
    check(irq===1'b0,"IRQ reset value is low");
    axi_read(LED_DATA,value);check(value===0,"LED data register reset readback");
    axi_read(BTN_GIER,value);check(value===0,"GIER reset is disabled");
    axi_read(BTN_IPIER,value);check(value===0,"IPIER reset is disabled");

    axi_write(LED_DATA,32'h000000a5,4'hf,0,0);
    check(leds===8'ha5,"LED full-word write reaches external pins");
    axi_read(LED_DATA,value);check(value===32'ha5,"LED write/readback");
    axi_write(LED_DATA,32'h0000003c,4'hf,0,7);
    check(leds===8'h3c,"AW before W is accepted");
    axi_write(LED_DATA,32'h000000c3,4'hf,7,0);
    check(leds===8'hc3,"W before AW is accepted");
    axi_write(LED_DATA,32'h0000005a,4'he,0,0);
    check(leds===8'h5a,"Vendor GPIO ignores WSTRB (full-word-only contract)");
    axi_write(LED_DATA,32'hffffff96,4'hf,0,0);
    axi_read(LED_DATA,value);check(value===32'h96,"LED upper 24 bits read as zero");

    @(negedge clk);buttons=5'b10101;
    repeat(20) @(posedge clk);
    axi_read(BTN_DATA,value);check(value===32'h15,"Five button inputs reach AXI readback");
    axi_read(BTN_IPISR,value);check((value&1)===1,"Button change sets status with enables off");
    check(irq===1'b0,"Disabled IRQ stays low despite pending status");
    clear_pending();
    axi_read(BTN_IPISR,value);check((value&1)===0,"Read-then-TOW clears pending status");

    axi_write(BTN_IPISR,32'h1,4'hf,0,0);
    axi_read(BTN_IPISR,value);check((value&1)===1,"TOW write-one toggles status from zero to one");
    axi_write(BTN_IPISR,32'h0,4'hf,0,0);
    axi_read(BTN_IPISR,value);check((value&1)===1,"TOW write-zero preserves pending status");
    clear_pending();

    axi_write(BTN_IPIER,32'h1,4'hf,0,0);
    axi_write(BTN_GIER,32'h80000000,4'hf,0,0);
    check(irq===1'b0,"Enables alone do not assert IRQ");
    @(negedge clk);buttons=5'b10100;
    repeat(20) @(posedge clk);
    check(irq===1'b1,"Button release asserts enabled level IRQ");
    axi_read(BTN_IPISR,value);check((value&1)===1,"Release sets channel-1 status");
    clear_pending();repeat(10) @(posedge clk);
    check(irq===1'b0,"Clearing pending deasserts IRQ");
    repeat(50) @(posedge clk);
    check(irq===1'b0,"Stable held button level does not retrigger IRQ");
    @(negedge clk);buttons=5'b10101;
    repeat(20) @(posedge clk);
    check(irq===1'b1,"New button press asserts IRQ");
    axi_write(BTN_GIER,32'h0,4'hf,0,0);repeat(5) @(posedge clk);
    check(irq===1'b0,"GIER gates the interrupt output");
    axi_read(BTN_IPISR,value);check((value&1)===1,"Disabling GIER preserves pending status");
    axi_write(BTN_GIER,32'h80000000,4'hf,0,0);repeat(5) @(posedge clk);
    check(irq===1'b1,"Re-enabling GIER exposes uncleared pending event");
    axi_write(BTN_IPIER,32'h0,4'hf,0,0);repeat(5) @(posedge clk);
    check(irq===1'b0,"IPIER independently gates IRQ");
    clear_pending();

    @(negedge clk);resetn=0;buttons=0;
    repeat(20) @(posedge clk);
    @(negedge clk);resetn=1;
    repeat(30) @(posedge clk);
    check(leds===8'h00 && irq===1'b0,"Reset restores LEDs and IRQ");
    axi_read(BTN_GIER,value);check(value===0,"Reset clears global interrupt enable");
    axi_read(BTN_IPIER,value);check(value===0,"Reset clears channel interrupt enable");
    axi_read(BTN_IPISR,value);check((value&1)===0,"Reset clears interrupt status");
    axi_write(LED_DATA,32'h00000001,4'hf,0,0);
    check(leds===8'h01,"AXI remains operational after reset");

    test_done=1;
    $display("GPIO_IP_SIM_PASS assertions=%0d",assertions_passed);
    #100;
    $finish;
  end

  initial begin
    #2000000;
    if(!test_done) begin test_failed=1;$fatal(1,"GPIO_IP_SIM_TIMEOUT");end
  end
endmodule
