# hw2_gpio_ip：LED 與按鈕 GPIO 子系統

此 IP 將兩顆原廠 AXI GPIO 2.0 與一組 AXI Interconnect 2.1 封裝成單一可重用周邊。它是自行整理介面、定義地址並封裝的 GPIO 子系統，內部 GPIO RTL 由 Xilinx IP 提供。

計數、防彈跳、兩秒暫停及 COUNT／PAUSE 狀態機仍由 ARM 的 C 程式執行。

## 識別與介面

- VLNV：`f115112124.org:user:hw2_gpio_ip:1.0`
- 顯示名稱：`HW2 LED and Button GPIO`
- HDL 頂層：`gpio_subsystem_wrapper`
- `S_AXI`：AXI4-Lite slave，32 位元資料、17 位元區域地址。
- `s_axi_aclk`：50 MHz 時脈。
- `s_axi_aresetn`：低有效 Reset。
- `led_o[7:0]`：八顆 LED 的高有效輸出。
- `btn_i[4:0]`：五顆按鈕的高有效輸入。
- `irq`：高電位有效的中斷通知，直到 GPIO pending 狀態清除為止。

## 內部結構

`S_AXI` 先進入一對二的 AXI Interconnect，再分別連至 LED GPIO 與按鈕 GPIO。LED GPIO 為 8 位元單通道輸出，中斷停用。按鈕 GPIO 為 5 位元單通道輸入，中斷啟用，輸出直接接到 `irq`。

17 位元區域地址對應 128 KiB 的整體窗口。在父系統配置基底位址 `0x41200000` 時，LED bank 為 `0x41200000`，按鈕 bank 為 `0x41210000`。父系統將區域地址傳入 IP，內部地址解碼不依賴父系統的絕對位址。

| 位置 | 相對整體 IP 的位移 | 用途 |
|---|---:|---|
| LED DATA | `0x00000` | 寫入 LED 顯示值，低八位元有效 |
| LED TRI | `0x00004` | 方向設定，0 代表輸出 |
| 按鈕 DATA | `0x10000` | 讀取按鈕，低五位元有效 |
| 按鈕 TRI | `0x10004` | 方向設定，1 代表輸入 |
| 按鈕 GIER | `0x1011C` | bit 31：全域中斷使能 |
| 按鈕 IPISR | `0x10120` | bit 0：通道一 pending 狀態，寫 1 反轉該位元 |
| 按鈕 IPIER | `0x10128` | bit 0：通道一中斷使能 |

ISR 必須先讀 IPISR，只將目前為 1 的 pending 位元寫回，才能清除既有通知。未 pending 時盲目寫 1，反而會把狀態設為 pending。

## 封裝原始資料

`scripts/package_gpio_ip.tcl` 定義所有內部 IP 參數、連線、位址與封裝識別。

封裝輸出包含 `component.xml`、`xgui/`、`src/` 中的 HDL 與三份子 IP `.xci`。所有 component 檔案引用均為相對路徑，沒有依賴原電腦的工作資料夾。

重建腳本若發現目標 IP 資料夾已存在會停止，避免覆寫既有封裝；可透過第一個 Tcl 參數指定新的 staging 輸出資料夾。封裝時的工作專案另置於 `.ip_packaging_work/`。

## 驗證範圍

- Vivado IP Packager integrity check 通過。
- 在全新 Vivado 專案的 IP Catalog 找到自己的 VLNV。
- 新 Block Design 可建立此 IP，映射 `0x41200000`／128 KiB，並完成 Validate 與輸出產生。
- 內層 GPIO 不會成為父系統 HWH 的獨立周邊，因此 ARM 使用記憶體映射讀寫小型介面，而不是依賴內層 GPIO 的自動裝置 ID。

## 參考

- AMD/Xilinx UG1118，Vivado 2018.3，Creating and Packaging Custom IP。
- AMD/Xilinx PG144，AXI GPIO 2.0，GPIO 與中斷暫存器定義。
- 內含 Xilinx 產生的 HDL 與子 IP 設定，保留原始第三方標示。
