----------------------------------------------------------------------------
-- 搖桿控制 WS2812 燈條顯示位置整合程式
-- 說明：透過 ADS1115 讀取搖桿 X/Y 軸，將其對應至 64 顆 WS2812 燈條的亮燈位置
-- 115.10.30  by chaosoyu
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all; -- 包含 l_px_arr_t 與色彩常數 (e.g. red, blue, black)

entity js is
    generic (
        sys_clk_freq : integer := 50_000_000
    );
    port (
        clk     : in std_logic;
        rst_n   : in std_logic;
        js_scl  : inout std_logic;
        js_sda  : inout std_logic;
        seg_led : out u8r_t;
        seg_com : out u8r_t;
        ws2812_out : out std_logic -- WS2812 串列訊號輸出
    );
end js;

architecture arch of js is

    -- 宣告 ADS1115 搖桿控制器元件
    component ads_js_ctrl is
        port (
            clk        : in std_logic;
            rst_n      : in std_logic;
            scl        : inout std_logic;
            sda        : inout std_logic;
            x_raw      : out u16_t;
            y_raw      : out u16_t;
            data_valid : out std_logic
        );
    end component;

    -- 宣告 WS2812 驅動元件
    component WS2812_ch is
        generic (
            led_num_max : integer := 64
        );
        port (
            clk, rst_n : in std_logic;
            ena      : in std_logic;
            busy     : out std_logic;
            rgb_data : in l_px_arr_t(0 to led_num_max - 1);
            D_out    : out std_logic;
            led_num  : in integer range 0 to led_num_max
        );
    end component;

    -- 內部訊號
    signal x_raw, y_raw : u16_t;
    signal x_latest, y_latest : u16_t := (others => '0');
    signal x_disp, y_disp : u16_t := (others => '0');
    signal data_valid : std_logic;
    signal data_valid_r : std_logic := '0';
    signal seg_data : string(1 to 8);

    -- 降頻計時器 (500ms，每秒更新 2 次)
    constant UPDATE_LIMIT : integer := sys_clk_freq / 2;
    signal update_cnt : integer range 0 to UPDATE_LIMIT := 0;

    -- WS2812 控制與資料訊號
    signal ws2812_ena : std_logic := '0';
    signal ws2812_busy : std_logic;
    signal led_pixels : l_px_arr_t(0 to 63) := (others => (others => '0')); -- 預設全滅 (黑色)
    signal target_led_idx : integer range 0 to 63 := 0;

    -- 更新觸發計時器 (讓 WS2812 定期刷新顯示，避免過於頻繁)
    signal refresh_cnt : integer range 0 to 500_000 := 0;

begin

    -- 0. 實體化七段顯示器模組
    u_seg : entity work.seg(arch)
        generic map(
            common_anode => '0'
        )
        port map(
            clk     => clk,
            rst_n   => rst_n,
            seg_led => seg_led,
            seg_com => seg_com,
            data    => seg_data,
            dot     => (others => '0')
        );

    -- 1. 實體化搖桿控制器
    u_ads : ads_js_ctrl
        port map(
            clk        => clk,
            rst_n      => rst_n,
            scl        => js_scl,
            sda        => js_sda,
            x_raw      => x_raw,
            y_raw      => y_raw,
            data_valid => data_valid
        );

    -- 2. 實體化 edge 抓取 data_valid 上升沿
    key_edge : entity work.edge(arch)
        port map(
            clk     => clk,
            rst_n   => rst_n,
            sig_in  => data_valid,
            rising  => data_valid_r,
            falling => open
        );

    -- 3. 上升沿觸發鎖存最新 ADC 數據
    process (clk, rst_n)
    begin
        if rst_n = '0' then
            x_latest <= (others => '0');
            y_latest <= (others => '0');
        elsif rising_edge(clk) then
            if data_valid_r = '1' then
                x_latest <= x_raw;
                y_latest <= y_raw;
            end if;
        end if;
    end process;

    -- 4. 每 500ms 將數據更新至顯示暫存器（七段顯示器用）
    process (clk, rst_n)
    begin
        if rst_n = '0' then
            update_cnt <= 0;
            x_disp <= (others => '0');
            y_disp <= (others => '0');
        elsif rising_edge(clk) then
            if update_cnt >= UPDATE_LIMIT - 1 then
                update_cnt <= 0;
                x_disp <= x_latest;
                y_disp <= y_latest;
            else
                update_cnt <= update_cnt + 1;
            end if;
        end if;
    end process;

    -- 七段顯示器內容：左 4 位顯 Y 軸，右 4 位顯 X 軸
    seg_data(1 to 4) <= to_string(to_integer(y_disp), 16#FFFF#, 16, 4);
    seg_data(5 to 8) <= to_string(to_integer(x_disp), 16#FFFF#, 16, 4);

    ----------------------------------------------------------------------------
    -- 5. 搖桿數值對應到 WS2812 燈泡位置與色彩控制
    ----------------------------------------------------------------------------
    -- 將 X 軸的 16 位元數值縮放對應到 0 ~ 63 的 LED 索引
    -- 假設 X 軸範圍約為 0x0036 (左) 到 0x53dd (右)，我們取高位元或做簡單位移
    target_led_idx <= to_integer(x_disp(15 downto 10)); -- 10#0至63#

    process (clk, rst_n)
    begin
        if rst_n = '0' then
            led_pixels <= (others => (others => '0')); -- 全部歸零（滅）
            ws2812_ena <= '0';
            refresh_cnt <= 0;
        elsif rising_edge(clk) then
            ws2812_ena <= '0'; -- 預設脉衝給一次

            if refresh_cnt = 500_000 then -- 每隔一段時間更新一次燈條狀態
                refresh_cnt <= 0;
                
                -- 將所有 LED 設為背景色（例如暗藍色或全黑）
                for i in led_pixels'range loop
                    led_pixels(i) <= x"001000"; -- 微弱綠光或自己定義的暗色
                end loop;

                -- 將搖桿指定的當前位置 LED 點亮成亮紅色
                led_pixels(target_led_idx) <= red; -- red 來自 itc_lcd 封包

                -- 啟動 WS2812 傳送
                if ws2812_busy = '0' then
                    ws2812_ena <= '1';
                end if;
            else
                refresh_cnt <= refresh_cnt + 1;
            end if;
        end if;
    end process;

    -- 6. 實體化 WS2812 驅動模組
    u_ws2812 : WS2812_ch
        generic map(
            led_num_max => 64
        )
        port map(
            clk      => clk,
            rst_n    => rst_n,
            ena      => ws2812_ena,
            busy     => ws2812_busy,
            rgb_data => led_pixels,
            D_out    => ws2812_out,
            led_num  => 64
        );

end arch;