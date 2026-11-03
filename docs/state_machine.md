# LED 計數與按鈕中斷狀態機

狀態機執行在 PS 的 ARM C 程式，來源為 [`main.c`](../firmware/hw2_demo/main.c)。
`paused = 0` 表示 COUNT，`paused = 1` 表示 PAUSE。INIT 是啟動時執行一次的初始化流程。

```mermaid
stateDiagram-v2
    [*] --> INIT
    state "初始化" as INIT
    state "COUNT 計數" as COUNT
    state "PAUSE 暫停" as PAUSE
    INIT --> COUNT: GPIO、GIC、Timer 就緒，LED=1
    COUNT --> COUNT: 每500ms加1，255之後回0
    COUNT --> PAUSE: 有效新按下，清零並計時2秒
    PAUSE --> PAUSE: 再次有效按下，重新計時2秒
    PAUSE --> COUNT: 到期後LED=1，500ms後再加1
```

按鈕中斷和防彈跳另行處理。ISR 清除 GPIO pending 並增加事件序號。
主程式觀察到序號改變後，將防彈跳期限設為現在加 20 ms。

```mermaid
stateDiagram-v2
    [*] --> WAIT_EVENT
    state "等待新事件" as WAIT_EVENT
    state "等待20ms穩定" as WAIT_STABLE
    WAIT_EVENT --> WAIT_STABLE: 觀察到新的IRQ事件序號
    WAIT_STABLE --> WAIT_STABLE: 再有新事件，重設20ms期限
    WAIT_STABLE --> WAIT_EVENT: 期限到，讀取按鈕並更新stable
```

到期時先計算 `pressed = current & ~stable & 0x1F`，再更新 `stable = current`。
`pressed` 非 0 才通知主狀態機。放開也會更新穩定狀態，長按同一顆按鈕不會連續重設。
等待防彈跳時，COUNT／PAUSE 仍持續執行。
