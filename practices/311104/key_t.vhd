library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity key_t is
    port (
        clk, rst_n : in  std_logic;
        key_row    : in  std_logic_vector(2 downto 0);
        key_col    : out std_logic_vector(2 downto 0);
        seg_led, seg_com : out u8r_t;
        dbg_a, dbg_b     : out u8r_t
    );
end key_t;

architecture arch of key_t is

    -- 可調參數
    constant SCAN_TICK : integer := 50000;   -- 每個掃描節拍的時脈數 (50 MHz 下約 1 ms)
    constant DEB       : integer := 10;      -- 連續偵測到幾個節拍才算按下 (約 10 ms)

    -- 共陽極七段: 段低電位點亮, 共陽極腳高電位選中
    constant SEG_ACTIVE : std_logic := '0';
    constant COM_SEL    : std_logic := '1';

    signal pressed : std_logic;
    signal key     : i4_t;

    signal scan_cnt     : integer range 0 to SCAN_TICK;
    signal current_col  : integer range 0 to 2;
    signal debounce_cnt : integer range 0 to DEB;
    signal held         : std_logic;

    signal rows_s1, rows_s2 : std_logic_vector(2 downto 0);

    signal seg_data : std_logic_vector(7 downto 0);  -- a b c d e f g dp, '1' 表示該段要亮

begin

    dbg_a <= (0 => pressed, others => '0');
    dbg_b(0 to 3) <= reverse(to_unsigned(key, 4));
    dbg_b(4 to 7) <= (others => '0');

    scan_proc : process (clk, rst_n)
        variable r : integer range 0 to 2;
    begin
        if rst_n = '0' then
            scan_cnt     <= 0;
            current_col  <= 0;
            key_col      <= "110";
            rows_s1      <= (others => '1');
            rows_s2      <= (others => '1');
            pressed      <= '0';
            held         <= '0';
            key          <= 0;
            debounce_cnt <= 0;
        elsif rising_edge(clk) then
            rows_s1 <= key_row;
            rows_s2 <= rows_s1;
            pressed <= '0';

            if scan_cnt = SCAN_TICK then
                scan_cnt <= 0;

                if rows_s2 /= "111" then
                    if    rows_s2(0) = '0' then r := 0;
                    elsif rows_s2(1) = '0' then r := 1;
                    else                         r := 2;
                    end if;

                    if debounce_cnt = DEB then
                        if held = '0' then
                            key     <= r * 3 + current_col + 1;
                            pressed <= '1';
                            held    <= '1';
                        end if;
                    else
                        debounce_cnt <= debounce_cnt + 1;
                    end if;
                else
                    debounce_cnt <= 0;
                    held         <= '0';
                    case current_col is
                        when 0 => current_col <= 1; key_col <= "101";
                        when 1 => current_col <= 2; key_col <= "011";
                        when 2 => current_col <= 0; key_col <= "110";
                    end case;
                end if;
            else
                scan_cnt <= scan_cnt + 1;
            end if;
        end if;
    end process;

    -- 七段圖樣 (1 = 該段要亮), 順序 a b c d e f g dp
    -- 【修正處】：改為對 seg_data 賦值，避免與 gen_seg 產生 Multiple Drivers 衝突
    with key select
        seg_data <= "11000000" when 0,
                    "11111001" when 1,
                    "10100100" when 2,
                    "10110000" when 3,
                    "10011001" when 4,
                    "10010010" when 5,
                    "10000010" when 6,
                    "11111000" when 7,
                    "10000000" when 8,
                    "10011000" when 9,
                    "00000010" when others;

     -- 依極性輸出: 共陽極時 SEG_ACTIVE='0', 圖樣會被反相
    gen_seg : for i in 0 to 7 generate
        seg_led(i) <= seg_data(i) when SEG_ACTIVE = '1' else not seg_data(i);
    end generate;

    -- 只選中最右邊 (第 7 位) 的數碼管
    gen_com : for i in 0 to 7 generate
        seg_com(i) <= COM_SEL when i = 7 else not COM_SEL;
    end generate;

end arch;