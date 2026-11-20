----------------------------------------------------------------------------
--用於測試uart_txt.vhd模組
--此uart_txt.vhd模組，tx與rx皆帶有stx(0x02)與etx(0x03)的啟始與結束標記
--測試結果：
--	 傳送時："PING" --> 接收到	02 50 49 4E 47 03 (stx PING etx)  
--	 接收時："HELLO" 在coolterm中要輸入 02 48 45 4C 4C 4F 03 
--	 coolterm是終端測試程式，可模擬uart
--115.11.6   by chaosoyu
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity uart_txt_top is
    generic (
        txt_len_max : integer := 28;
        baud        : integer := 9_600
    );
    port (
        -- 系統時脈與重置
        clk   : in std_logic; -- 板載時脈 (例如 50MHz)
        rst_n : in std_logic; -- 復位按鍵 (低電位觸發)

        -- UART 實體接腳 (對接 USB-to-TTL 轉接器或板載 UART)
        uart_rx : in std_logic;  -- RX Pin
        uart_tx : out std_logic; -- TX Pin

        -- seg
        seg_led, seg_com : out u8r_t;

        -- key 3X3
        key_row : in unsigned(0 to 2);
        key_col : out unsigned(0 to 2);

        led_r : out std_logic -- 接收中指示燈
    );
end uart_txt_top;

architecture arch of uart_txt_top is

    -- 內部訊號
    signal tx_ena : std_logic := '0';
    signal tx_busy : std_logic;
    signal tx_data : string(1 to txt_len_max) := (others => ' ');
    signal tx_len : integer range 1 to txt_len_max := 1;

    signal rx_busy : std_logic;
    signal rx_data : string(1 to txt_len_max);
    signal rx_len : integer range 1 to txt_len_max;

    -- key
    signal pressed, pressed_i : std_logic;
    signal key : i4_t;

    -- seg
    signal seg_data : string(1 to 8) := (others => ' ');
    signal dot : u8r_t := (others => '0');

    -- RX 降緣檢測 (用來判斷接收完成 moment)
    signal rx_done : std_logic;

begin

    --接收時紅色led會閃爍
    led_r <= not uart_rx;

    -- 實體化已修改保護機制的 uart_txt 模組
    uart_txt_inst : entity work.uart_txt
        generic map(
            txt_len_max => txt_len_max,
            baud        => baud
        )
        port map(
            clk     => clk,
            rst_n   => rst_n,
            uart_rx => uart_rx,
            uart_tx => uart_tx,
            tx_ena  => tx_ena,
            tx_busy => tx_busy,
            tx_data => tx_data,
            tx_len  => tx_len,
            rx_busy => rx_busy,
            rx_data => rx_data,
            rx_len  => rx_len
        );

    -- 實例化 edge 檢測模組
    edge_rx_inst : entity work.edge(arch)
        port map(
            clk     => clk,
            rst_n   => rst_n,
            sig_in  => rx_busy,
            rising  => open,
            falling => rx_done -- 接收完成時脈衝亮 1 個 clk
        );

    key_inst : entity work.key_3X3(arch)
        port map(
            clk     => clk,
            rst_n   => rst_n,
            key_row => key_row,
            key_col => key_col,
            pressed => pressed_i,
            key     => key
        );

    edge_inst : entity work.edge(arch)
        port map(
            clk     => clk,
            rst_n   => rst_n,
            sig_in  => pressed_i,
            rising  => pressed,
            falling => open
        );

    seg_inst : entity work.seg(arch)
        generic map(
            common_anode => '0'
        )
        port map(
            clk     => clk,
            rst_n   => rst_n,
            seg_led => seg_led,
            seg_com => seg_com,
            data    => seg_data,
            dot     => dot
        );
    --------------------------------------------------------------------
    -- 主控制邏輯：自動 Echo 迴響與按鈕發送控制
    --------------------------------------------------------------------
    process (clk, rst_n)
    begin
        if rst_n = '0' then
            tx_ena <= '0';
            tx_data <= (others => ' ');
            tx_len <= 1;
            seg_data <= "        ";
        elsif rising_edge(clk) then
            tx_ena <= '0'; -- 預設只持續一個 Pulse

            if rx_done = '1' and tx_busy = '0' then
                -- 觸發 1：收到 CoolTerm 傳來的字串時，自動將收到的字串 Echo 回去
                --打開 CoolTerm 選單：Connection -> Send String...切換至 Hex 模式因為需要帶
                -- STX=0x02 與 ETX=0x03 標頭標尾
                -- 輸入 Hex 碼 : 02 48 45 4C 4C 4F 03
                tx_data(1 to rx_len) <= rx_data(1 to rx_len);
                tx_len <= rx_len;
                --tx_len <= 28;
                --tx_data <= "ID9901OQ00700030SQ#40$1200" & CR & LF;
                tx_ena <= '1';
                seg_data <= rx_data(1 to 8);

            elsif pressed = '1' and key = 0 then
                -- 觸發 2：按下板子按鈕0
                -- CoolTerm 接收視窗會顯示 PING 封包（若顯示 Hex 模式則會看到 02 50 49 4E 47 03）
                tx_data(1 to 4) <= "PING";
                tx_len <= 4;
                tx_ena <= '1';
            end if;
        end if;
    end process;

end arch;
