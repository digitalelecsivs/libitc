library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity key_t is
    port (
        clk, rst_n : in std_logic;
        key_row : in std_logic_vector(3 downto 0);
        key_col : out std_logic_vector(2 downto 0);
        dbg_a, dbg_b : out std_logic_vector(7 downto 0)
    );
end key_t;

architecture arch of key_t is
    constant SCAN_DIV : integer := 50000; --50MHz/50000=1kHz
    constant DEB : integer := 10; --約10ms

    signal scan_cnt : integer range 0 to SCAN_DIV;
    signal col_idx : integer range 0 to 2;
    signal deb_cnt : integer range 0 to DEB;
    signal held : std_logic;

    signal rows_s1, rows_s2 : std_logic_vector(2 downto 0);

    signal pressed : std_logic;
    signal key : integer range 0 to 9;

begin

    dbg_a <= (0 => pressed, others => '0');
    dbg_b(3 downto 0) <= std_logic_vector(to_unsigned(key, 4));
    dbg_b(7 downto 4) <= (others => '0');


    with col_idx select
        key_col <= "110" when 0,
                   "101" when 1,
                   "011" when others;


    scan_proc : process (clk, rst_n)
        variable r : integer range 0 to 2;
    begin
        if rst_n = '0' then
            scan_cnt <= 0;
            col_idx <= 0;
            deb_cnt <= 0;
            held <= '0';
            rows_s1 <= (others => '1');
            rows_s2 <= (others => '1');
            pressed <= '0';
            key <= 8;
        elsif rising_edge(clk) then
            rows_s1 <= key_row(2 downto 0);
            rows_s2 <= rows_s1;
            pressed <= '0';

            if scan_cnt = SCAN_DIV then
                scan_cnt <= 0;

                if rows_s2 /= "111" then
                    if rows_s2(0) = '0' then
                        r := 0;
                    elsif rows_s2(1) = '0' then
                        r := 1;
                    else r := 2;
                    end if;

                    if deb_cnt = DEB then
                        if held = '0' then
                            key <= r * 3 + col_idx + 1;
                            pressed <= '1';
                            held <= '1';
                        end if;
                    else
                        deb_cnt <= deb_cnt + 1;
                    end if;
                else
                    deb_cnt <= 0;
                    held <= '0';
                    if col_idx = 2 then
                        col_idx <= 0;
                    else
                        col_idx <= col_idx + 1;
                    end if;
                end if;
            else
                scan_cnt <= scan_cnt + 1;
            end if;
        end if;
    end process;
end arch;