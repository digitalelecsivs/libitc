----------------------------------------------------------------------------
-- WS2812跑馬燈 (支援指撥開關切換亮燈排數)
-- 說明：透過 50MHz 時脈與 WS2812_ch 驅動模組，實現 64 顆 LED 跑馬燈效果。
-- 顏色控制：SW(2)=綠, SW(1)=紅, SW(0)=藍 (可混色)
-- 排數控制：SW(7 downto 6) => "00": 不亮, "01": 亮一排, "10": 亮兩排, "11": 亮三排
-- 115.11.04   by chaosoyu
----------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity WS2812_test is
    port (
        clk, rst_n : in std_logic;
        sw         : in std_logic_vector(7 downto 0);
        D_out      : out std_logic
    );
end WS2812_test;

architecture arch of WS2812_test is
    type state_t is (idle, sure, work);
    signal mode_t : state_t := idle;

    signal sw_d : std_logic_vector(7 downto 0) := (others => '0');
    signal ws_ena : std_logic := '0';
    signal ws_busy : std_logic;
    signal ws_busy_f : std_logic;

    constant C_LED_MAX : integer := 64;
    signal led_num : integer range 0 to C_LED_MAX;
    signal rgb_data : l_px_arr_t(0 to C_LED_MAX - 1);

    -- 50MHz Clock 下，100ms 移位一次
    constant C_SHIFT_PERIOD : integer := 5_000_000;
    signal timer_cnt : integer range 0 to C_SHIFT_PERIOD := 0;
    signal auto_tick : std_logic := '0';

    signal shift_cnt : integer range 0 to C_LED_MAX - 1 := 0;
    signal active_color : l_px_t;

    -- 元件宣告：消彈跳 (Debounce)
    component debounce is
        generic (
            stable_time : integer := 10
        );
        port (
            clk, rst_n : in std_logic;
            sig_in     : in std_logic;
            sig_out    : out std_logic
        );
    end component;

    -- 元件宣告：WS2812 驅動器
    component WS2812_ch is
        generic (
            led_num_max : integer := C_LED_MAX
        );
        port (
            clk, rst_n : in std_logic;
            ena        : in std_logic;
            busy       : out std_logic;
            rgb_data   : in l_px_arr_t(0 to led_num_max - 1);
            D_out      : out std_logic;
            led_num    : in integer range 0 to led_num_max
        );
    end component;

    -- 元件宣告：邊緣檢測器 (Edge Detector)
    component edge is
        port (
            clk, rst_n : in std_logic;
            sig_in     : in std_logic;
            rising     : out std_logic;
            falling    : out std_logic
        );
    end component;

begin

    ---------------------------------------------------------------------------
    -- 硬體元件實體化
    ---------------------------------------------------------------------------
    components : block begin
        -- 8 個開關的彈跳消除
        gen_sw_debounce : for i in 0 to 7 generate
            sw_deb : debounce
                generic map(stable_time => 100)
                port map(
                    clk     => clk,
                    rst_n   => rst_n,
                    sig_in  => sw(i),
                    sig_out => sw_d(i)
                );
        end generate gen_sw_debounce;

        -- WS2812 序列驅動核心
        WS2812_inst : WS2812_ch
            generic map(
                led_num_max => C_LED_MAX
            )
            port map(
                clk      => clk,
                rst_n    => rst_n,
                ena      => ws_ena,
                busy     => ws_busy,
                rgb_data => rgb_data,
                D_out    => D_out,
                led_num  => led_num
            );

        -- 捕捉 WS2812 忙碌信號的下降緣
        edge_busy : edge
            port map(
                clk     => clk,
                rst_n   => rst_n,
                sig_in  => ws_busy,
                rising  => open,
                falling => ws_busy_f
            );
    end block components;

    ---------------------------------------------------------------------------
    -- 定時產生器：每 100ms 觸發一次 auto_tick
    ---------------------------------------------------------------------------
    timer_process : process (clk, rst_n) begin
        if rst_n = '0' then
            timer_cnt <= 0;
            auto_tick <= '0';
        elsif rising_edge(clk) then
            auto_tick <= '0';
            if timer_cnt < C_SHIFT_PERIOD - 1 then
                timer_cnt <= timer_cnt + 1;
            else
                timer_cnt <= 0;
                auto_tick <= '1';
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- 顏色設置：SW(2)=綠, SW(1)=紅, SW(0)=藍
    ---------------------------------------------------------------------------
    active_color <= (sw_d(2) & "0000000" & sw_d(1) & "0000000" & sw_d(0) & "0000000")
        when (sw_d(2 downto 0) /= "000") else X"00FF00"; -- 預設為綠光

    ---------------------------------------------------------------------------
    -- 主控狀態機：控制跑馬燈移位與發送時序
    ---------------------------------------------------------------------------
    Main_Process : block begin
        process (clk, rst_n) begin
            if rst_n = '0' then
                mode_t <= idle;
                ws_ena <= '0';
                shift_cnt <= 0;
                led_num <= C_LED_MAX;
                for i in 0 to C_LED_MAX - 1 loop
                    rgb_data(i) <= (others => '0');
                end loop;
            elsif rising_edge(clk) then
                case mode_t is

                    when idle =>
                        ws_ena <= '0';
                        if auto_tick = '1' then
                            mode_t <= sure;

                            -- 更新跑馬燈位置指標
                            if shift_cnt < C_LED_MAX - 1 then
                                shift_cnt <= shift_cnt + 1;
                            else
                                shift_cnt <= 0;
                            end if;

                            -- 根據 SW(7 downto 6) 決定點亮的排數
                            for i in 0 to C_LED_MAX - 1 loop
                                case sw_d(7 downto 6) is
                                    when "00" => -- 00: 不亮
                                        rgb_data(i) <= X"000000";

                                    when "01" => -- 01: 亮一排
                                        if i = shift_cnt then
                                            rgb_data(i) <= active_color;
                                        else
                                            rgb_data(i) <= X"000000";
                                        end if;

                                    when "10" => -- 10: 亮兩排 (間隔 16 顆)
                                        if i = shift_cnt or i = (shift_cnt + 8) mod C_LED_MAX then
                                            rgb_data(i) <= active_color;
                                        else
                                            rgb_data(i) <= X"000000";
                                        end if;

                                    when others => -- "11": 亮三排 (間隔 16 顆與 32 顆)
                                        if i = shift_cnt or i = (shift_cnt + 8) mod C_LED_MAX or i = (shift_cnt + 16) mod C_LED_MAX then
                                            rgb_data(i) <= active_color;
                                        else
                                            rgb_data(i) <= X"000000";
                                        end if;
                                end case;
                            end loop;
                        end if;

                    when sure =>
                        ws_ena <= '1';
                        -- 等待驅動晶片響應 busy 高電位
                        if ws_busy = '1' then
                            mode_t <= work;
                        end if;

                    when work =>
                        ws_ena <= '0';
                        -- 等待傳輸完成 (busy 下降緣) 後返回 idle
                        if ws_busy_f = '1' then
                            mode_t <= idle;
                        end if;

                end case;
            end if;
        end process;
    end block Main_Process;

end arch;