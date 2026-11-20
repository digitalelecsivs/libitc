----------------------------------------------------------------------------
--115學年度數位電子術科參考試題一     ***試題名稱：資訊顯示與座標控制系統 ***
--實作方塊一  :  EP3C16Q240C8N    
--115.10.18 by chaosoyu
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity Board1_115_top is
    port (
        clk   : in std_logic;
        rst_n : in std_logic;

        -- 3x3 矩陣按鍵
        key_row : in unsigned(0 to 2);
        key_col : out unsigned(0 to 2);

        dbg_a : out unsigned(0 to 5);
        -- UART1 發送端 (接至 Wi-Fi 模組 1)
        uart_tx : out std_logic
    );
end Board1_115_top;

architecture arch of Board1_115_top is

    signal key_pressed : std_logic;
    signal key_code : integer range 0 to 9;
    signal key_pressed_r : std_logic;

    -- UART 介面訊號
    signal tx_ena : std_logic := '0';
    signal tx_busy : std_logic;
    signal tx_data : u8_t := (others => '0');

begin

    -- 3x3 按鍵掃描模組
    key_3x3_inst : entity work.key_3x3(arch)
        port map(
            clk     => clk,
            rst_n   => rst_n,
            key_row => key_row,
            key_col => key_col,
            pressed => key_pressed,
            key     => key_code
        );

    -- 整合型 UART 模組 (發送端)
    uart_inst : entity work.uart(arch)
        generic map(
            baud => 9600
        )
        port map(
            clk     => clk,
            rst_n   => rst_n,
            uart_rx => '1', -- 未使用接收，拉高維持 idle
            uart_tx => uart_tx,
            tx_ena  => tx_ena,
            tx_busy => tx_busy,
            tx_data => tx_data,
            rx_busy => open,
            rx_err  => open,
            rx_data => open
        );

    -- 按鍵正緣檢測模組
    key_edge : entity work.edge(arch)
        port map(
            clk     => clk,
            rst_n   => rst_n,
            sig_in  => key_pressed,
            rising  => key_pressed_r,
            falling => open
        );

    -- 按鍵觸發傳送控制
    process (clk, rst_n)
    begin
        if rst_n = '0' then
            dbg_a(3 to 0) <= (others => '1');
            tx_ena <= '0';
            tx_data <= (others => '0');
        elsif rising_edge(clk) then
            tx_ena <= '0';

            -- 當檢測到 KEY 按下正緣時發送實際的按鍵編號 (0~8)
            if (key_pressed_r = '1') then
                if tx_busy = '0' then
                    tx_data <= u8_t(to_unsigned(key_code, 8));
                    tx_ena <= '1';
                end if;
            end if;
        end if;
    end process;

    -- 將 key_code 直接反相輸出至 dbg_a，觀察是否隨按鍵即時改變
    dbg_a(0 to 3) <= not u4_t(to_unsigned(key_code, 4));
    dbg_a(4) <= tx_busy; -- 顯示 UART 的 busy 狀態 
    dbg_a(5) <= key_pressed; -- 顯示按鍵觸發狀態
end arch;
