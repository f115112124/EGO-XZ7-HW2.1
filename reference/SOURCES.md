# EGO-XZ7 設定來源

本工程使用 Vivado／SDK 2018.3、`xc7z020clg484-1`，以手動 PS 設定及 XDC 實作，未安裝原廠 Board Files。

- [原廠 EGO-XZ7 規格](https://www.nexora-tech.com.tw/agent-products/egoxz7)：器件、PL LED 與按鈕數量。
- [Chee-En 的同版工程](https://github.com/Chee-En/SoC_HW2/blob/ae65b9ac9be584e01492d3f0592252b8c66a6e08/hw2/hw2/hw2.xpr)：Vivado 2018.3、器件與 EGO 板卡識別。
- [PS7 匯出參數](https://github.com/Chee-En/SoC_HW2/blob/ae65b9ac9be584e01492d3f0592252b8c66a6e08/hw2/hw2/hw2.srcs/sources_1/bd/design_1/hw_handoff/design_1_bd.tcl)：DDR、PLL、MIO 與 UART1 設定；本工程另外明確設定 GP0、IRQ、FCLK、Reset，停用未使用的 WP／WDT EMIO。
- [實際 I/O 報告](https://github.com/Chee-En/SoC_HW2/blob/ae65b9ac9be584e01492d3f0592252b8c66a6e08/hw2/hw2/hw2.runs/impl_1/design_1_wrapper_io_placed.rpt)：LED Bank 33 為 LVCMOS33；PL 按鈕 Bank 34 為 LVCMOS25。

硬體連線與韌體為本次重新建立。ISR 僅清除 GPIO 中斷並記錄事件；防彈跳、兩秒暫停與 LED 更新均在主程式執行。
