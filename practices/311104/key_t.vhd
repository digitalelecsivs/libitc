library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity key_t is
    port (
        clk, rst_n : in std_logic;
        key_row : in std_logic_vector(2 downto 0);
        key_col : out std_logic_vector(2 downto 0);
        seg_led, seg_com : out u8r_t;
        dbg_a, dbg_b : out u8r_t
    );
end key_t;

architecture arch of key_t is

    signal pressed : std_logic;
    signal key : i4_t;
    signal buf : string(1 to 8); 

    signal scan_cnt : unsigned(15 downto 0);
    signal current_col : integer range 0 to 2;
    signal raw_pressed : std_logic;
    signal raw_key : i4_t;
    
    signal debounce_cnt : integer range 0 to 100000;

begin

    dbg_a <= (0 => pressed, others => '0');
    dbg_b(0 to 3) <= reverse(to_unsigned(key, 4));
    dbg_b(4 to 7) <= (others => '0');

    process (clk, rst_n)
    begin
        if rst_n = '0' then
            scan_cnt <= (others => '0');
            current_col <= 0;
            key_col <= "111";
            raw_pressed <= '0';
            raw_key <= 0;
            pressed <= '0';
            key <= 0;
            debounce_cnt <= 0;
        elsif rising_edge(clk) then
            pressed <= '0';
            if scan_cnt = 50000 then
                scan_cnt <= (others => '0');
                case current_col is
                    when 0 =>
                        key_col <= "110"; 
                        if key_row(0) = '0' then raw_key <= 1; raw_pressed <= '1';
                        elsif key_row(1) = '0' then raw_key <= 4; raw_pressed <= '1';
                        elsif key_row(2) = '0' then raw_key <= 7; raw_pressed <= '1';
                        else
                            raw_pressed <= '0';
                        end if;
                        current_col <= 1;
                        
                    when 1 =>
                        key_col <= "101"; 
                        if key_row(0) = '0' then raw_key <= 2; raw_pressed <= '1';
                        elsif key_row(1) = '0' then raw_key <= 5; raw_pressed <= '1';
                        elsif key_row(2) = '0' then raw_key <= 8; raw_pressed <= '1';
                        else
                            raw_pressed <= '0';
                        end if;
                        current_col <= 2;
                        
                    when 2 =>
                        key_col <= "011"; 
                        if key_row(0) = '0' then raw_key <= 3; raw_pressed <= '1';
                        elsif key_row(1) = '0' then raw_key <= 6; raw_pressed <= '1';
                        elsif key_row(2) = '0' then raw_key <= 9; raw_pressed <= '1';
                        else
                            raw_pressed <= '0';
                        end if;
                        current_col <= 0;
                        
                    when others =>
                        current_col <= 0;
                end case;

                if raw_pressed = '1' then
                    if debounce_cnt = 10 then 
                        key <= raw_key;
                        pressed <= '1';
                        debounce_cnt <= 0;
                    else
                        debounce_cnt <= debounce_cnt + 1;
                    end if;
                else
                    debounce_cnt <= 0;
                end if;

            else
                scan_cnt <= scan_cnt + 1;
            end if;
        end if;
    end process;

    seg_inst : entity work.seg(arch)
        port map(
            clk     => clk,
            rst_n   => rst_n,
            seg_led => seg_led,
            seg_com => seg_com,
            data    => buf,
            dot     => (others => '0')
        );

    process (clk, rst_n) begin
        if rst_n = '0' then
            buf <= (others => ' ');
        elsif rising_edge(clk) and pressed = '1' then
            buf <= buf(2 to 8) & to_string(key, 15, 16, 1)(1);
        end if;
    end process;

end arch;