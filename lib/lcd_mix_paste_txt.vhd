library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity lcd_mix is
    port (
        -- system
        clk, rst_n : in std_logic;
        -- user
        x            : in integer range -127 to 127;
        y            : in integer range -159 to 159;
        font_start   : in std_logic;
        font_busy    : out std_logic;
        text_size    : in integer range 1 to 12;
        text_data    : in string(1 to 12);
        font_mode    : in integer range 0 to 2; -- 0:ASCII, 1:Num 3x3, 2:Num 4x3
        addr         : out l_addr_t;
        bg_color     : in l_px_t;
        text_color_array : in l_px_arr_t(1 to 12);
        clear        : in std_logic;
        -- lcd
        lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
    );
end lcd_mix;

architecture arch of lcd_mix is
    -- 狀態機
    type status_t is (idle, draw_txt, clear_screen);
    signal status : status_t;
    
    -- 內部訊號 (Signals)
    signal color : l_px_t;
    signal wr_ena : std_logic;
    signal start_draw : std_logic;
    signal l_addr : l_addr_t; -- 連接到 VRAM 的位址
    signal l_data : l_px_t; -- 連接到 VRAM 的資料
    
    -- ROM 相關訊號
    signal l_addr_1 : l_addr_t; -- ROM 1 (ASCII) 的位址
    signal l_addr_n : l_addr_t; -- ROM 2 (Numeric) 的位址
    signal q_1 : std_logic_vector(0 downto 0); -- ROM 1 的輸出
    signal q_n : std_logic_vector(0 downto 0); -- ROM 2 的輸出
    
    -- 計數器訊號 (Registers)
    signal data_y : integer range 0 to 53;
    signal data_x : integer range 0 to 32;
    signal count : integer range 0 to 11;
    signal pixel_count_x, pixel_count_y : integer range 0 to 12;

begin
    -- 邊緣偵測器 (保持併發)
    edge_inst : entity work.edge(arch)
        port map(
            clk     => clk,
            rst_n   => rst_n,
            sig_in  => font_start,
            rising  => start_draw,
            falling => open
        );
    -- LCD 底層驅動 (保持併發)
    lcd_inst : entity work.lcd(arch)
        port map(
            clk        => clk,
            rst_n      => rst_n,
            lcd_sclk   => lcd_sclk,
            lcd_mosi   => lcd_mosi,
            lcd_ss_n   => lcd_ss_n,
            lcd_dc     => lcd_dc,
            lcd_bl     => lcd_bl,
            lcd_rst_n  => lcd_rst_n,
            brightness => 100,
            wr_ena     => wr_ena,
            addr       => l_addr,
            data       => l_data
        );

    -- 字型 ROM 1 (ASCII) (保持併發)
    Font_inst : entity work.Font(syn)
        port map(
            address => std_logic_vector(to_unsigned(l_addr_1, 15)),
            clock   => clk,
            q       => q_1
        );
    -- 字型 ROM 2 (Numeric) (保持併發)
    Font_Numeric_inst : entity work.Font_numeric(syn)
        port map(
            address => std_logic_vector(to_unsigned(l_addr_n, 15)),
            clock   => clk,
            q       => q_n
        );

    -- ======================================================================
    -- *** 唯一的主 Process (合併了所有邏輯) ***
    -- ======================================================================
    process (clk, rst_n)
        -- 中介計算使用變數 (Variables)
        variable X_pos_v : integer;
        variable Y_pos_v : integer;
        variable l_addr_1_v, l_addr_n_v : l_addr_t;
        variable first_px_1_v, first_px_N_v : l_addr_t;
        variable q_v : std_logic;
        variable is_invisible_v : std_logic;
        variable lcd_x_v : integer range 0 to 1;
        
    begin
        if rst_n = '0' then
            -- 重置所有訊號
            wr_ena <= '0';
            status <= clear_screen;
            count <= 0;
            data_x <= 0;
            data_y <= 0;
            addr <= 0;
            l_addr <= 0;
            font_busy <= '0';
            color <= (others => '0');
            pixel_count_x <= 0;
            pixel_count_y <= 0;
            l_addr_1 <= 0;
            l_addr_n <= 0;
            l_data <= (others => '0');
            
        elsif rising_edge(clk) then

            -- ==========================================================
            --  1. 併發計算區 (使用當前的計數器值)
            -- ==========================================================
            
            -- 計算 'W' 字元的微調 (僅 font_mode 0)
            if font_mode = 0 and character'pos(text_data(count + 1)) = 87 then
                lcd_x_v := 1;
            else
                lcd_x_v := 0;
            end if;

            -- 計算 ROM 偏移量 (first_px)
            first_px_1_v := 950 when (text_data(count + 1) = 'd') and (text_data(count + 2) = 'C') else (character'pos(text_data(count + 1)) - 32) * 10 + lcd_x_v;
            
            first_px_N_v := (character'pos(text_data(count + 1)) - 48) * 32 + 1 
                            when character'pos(text_data(count + 1)) > 50 else -- ASCII '2' 是 50
                            (character'pos(text_data(count + 1)) - 48) * 32;

            -- 計算 ROM 位址 (l_addr_p)
            l_addr_1_v := 1056 * data_y + data_x + first_px_1_v;
            l_addr_n_v := 320 * data_y + data_x + first_px_N_v;

            -- 檢查非數字字元 (僅 font_mode 1 or 2)
            is_invisible_v := '1' when (font_mode /= 0) and ((character'pos(text_data(count + 1)) < 48) or (character'pos(text_data(count + 1)) > 57)) else
                              '0';

            -- 選擇 ROM 輸出 (q)
            -- *** 關鍵：q_1 和 q_n 是 *上一個* 時脈週期的 ROM 輸出 ***
            if font_mode = 0 then
                q_v := q_1(0);
            else
                q_v := q_n(0);
            end if;
            
            -- ==========================================================
            --  2. 像素混合器 (Pixel Mixer)
            -- ==========================================================
            if q_v = '1' or status = clear_screen or is_invisible_v = '1' then
                l_data <= bg_color;
            else
                l_data <= color;
            end if;

            -- ==========================================================
            --  3. 狀態機 (FSM) 與計數器邏輯
            -- ==========================================================
            
            -- 預設輸出 (在 FSM 外設定，在 FSM 內覆蓋)
            wr_ena <= '0'; -- 預設不寫入

            case status is
                when idle =>
                    font_busy <= '0';
                    wr_ena <= '0'; 
                    
                    if start_draw = '1' and clear = '0' then
                        font_busy <= '1';
                        status <= draw_txt;
                        -- 重置所有計數器
                        count <= 0;
                        data_x <= 0;
                        data_y <= 0;
                        pixel_count_x <= 0;
                        pixel_count_y <= 0;
                        color <= text_color_array(1);
                        
                    elsif clear = '1' then
                        font_busy <= '1';
                        addr <= 0;
                        status <= clear_screen;
                    end if;

                when draw_txt =>
                    if (clear = '1') then
                        status <= clear_screen;
                        font_busy <= '0';
                    else
                        font_busy <= '1';
                        
                        -- A. 計算 VRAM 位址
                        if font_mode = 0 then
                            X_pos_v := data_x * text_size + pixel_count_x + x + (count * 10 * text_size);
                            Y_pos_v := data_y * text_size + pixel_count_y + y;
                        elsif font_mode = 1 then -- 3x3 佈局 (40px 間距)
                            X_pos_v := data_x + x + (count * 40);
                            Y_pos_v := data_y + y;
                        else -- font_mode = 2 (4x3 佈局, 32px 間距)
                            X_pos_v := data_x + x + (count * 32);
                            Y_pos_v := data_y + y;
                        end if;
                        
                        l_addr <= X_pos_v + 128 * Y_pos_v;

                        -- B. 計算寫入致能 (透明 & 裁剪)
                        if (q_v = '0') and (is_invisible_v = '0') and
                           (X_pos_v <= 127) and (Y_pos_v <= 159) and 
                           (Y_pos_v >= 0) and (X_pos_v >= 0) then
                            wr_ena <= '1';
                        else
                            wr_ena <= '0';
                        end if;

                        -- C. 更新計數器 (為下一個時脈週期)
                        if font_mode = 0 then
                            -- 模式 0: ASCII 縮放 (5 層迴圈)
                            if (pixel_count_x < text_size) then
                                if pixel_count_y < text_size then
                                    pixel_count_y <= pixel_count_y + 1;
                                else
                                    pixel_count_y <= 0;
                                    pixel_count_x <= pixel_count_x + 1;
                                end if;
                            else
                                pixel_count_x <= 0;
                                if data_x + 1 = 11 then
                                    data_x <= 0;
                                    if data_y + 1 = 20 then
                                        data_y <= 0;
                                        if count = 11 then
                                            status <= idle;
                                            count <= 0;
                                        else
                                            count <= count + 1;
                                        end if;
                                    else
                                        data_y <= data_y + 1;
                                    end if;
                                else
                                    data_x <= data_x + 1;
                                end if;
                                color <= text_color_array(count + 1); 
                            end if;
                            
                        elsif font_mode = 1 or font_mode = 2 then
                            -- 模式 1 & 2: 數字 (3 層迴圈)
                            if data_x + 1 = 32 then
                                data_x <= 0;
                                if data_y + 1 = 53 then
                                    data_y <= 0;
                                    if count = 11 then 
                                        status <= idle;
                                        count <= 0;
                                    else
                                        count <= count + 1; 
                                    end if;
                                else
                                    data_y <= data_y + 1; 
                                end if;
                            else
                                data_x <= data_x + 1; 
                            end if;
                            color <= text_color_array(count + 1);
                        end if;
                    end if;

                when clear_screen =>
                    font_busy <= '1';
                    wr_ena <= '1'; -- 在清除/圖片模式下，永遠寫入
                    
                    if addr = addr'high then
                        addr <= 0;
                        font_busy <= '0';
                        status <= idle;
                    else
                        addr <= addr + 1;
                    end if;
                    
                    l_addr <= addr; -- VRAM 位址 = 掃描計數器

                when others =>
                    status <= idle;
            end case;
            
            -- ==========================================================
            --  4. 併發輸出區 (驅動 ROM)
            -- ==========================================================
            
            -- 將本週期計算出的 ROM 位址，指派給 ROM 的輸入埠
            -- ROM 會在 *下一個* 時脈週期回傳 q_1/q_n
            l_addr_1 <= l_addr_1_v;
            l_addr_n <= l_addr_n_v;

        end if;
    end process;
    
    -- (所有併發訊號指派都已被移入 'process' 區塊)

end arch;