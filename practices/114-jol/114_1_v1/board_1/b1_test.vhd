library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity b1_test is
	port (
		clk   : in std_logic;
		rst_n : in std_logic;
		dbg_a : out u4r_t;
		dbg_b : out u4r_t;
		--uart
		uart_rx : in std_logic; -- receive pin
		uart_tx : out std_logic -- transmit pin
	);
end b1_test;

architecture arch of b1_test is
	--key board
	signal pressed_i : std_logic;
	signal pressed : std_logic;
	signal key : integer range 0 to 15;
	--uart
	signal rx_start, rx_done, tx_mode : std_logic;
	signal tx_ena, tx_busy, rx_busy, rx_err, tx_ena_e : std_logic;
	signal tx_data, rx_data : string(1 to 12);
	signal tx_len, rx_len : integer range 1 to 12;
	
	type state is (IDLE, SEND_PULSE);
	signal CNT : unsigned(20 downto 0);
begin
	uart_txt : entity work.uart_txt(arch)
		generic map(
			txt_len_max => 12,
			baud        => 115200 -- data link baud rate in bits/second
		)
		port map(
			-- system
			clk   => clk,
			rst_n => rst_n,
			-- uart
			uart_rx => uart_rx, -- receive pin
			uart_tx => uart_tx, -- transmit pin
			-- user logic
			tx_ena  => tx_ena,  -- initiate transmission
			tx_busy => tx_busy, -- transmission in progress
			tx_data => tx_data, -- data to transmit
			tx_len  => tx_len,
			tx_mode => tx_mode,
			rx_busy => rx_busy, -- data reception in progress
			rx_data => rx_data, -- data received
			rx_len  => rx_len
		);

	rx_edge : entity work.edge(arch)
		port map(
			clk     => clk, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => rx_busy, --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => open,    --正緣 '1'觸發
			falling => rx_done  --負緣 open=開路
		);

	process (clk)
	begin
		if rst_n = '0' then
			dbg_a <= not "0000";
			dbg_b <= not "0000";
			tx_ena <= '0';
		elsif rising_edge(clk) then
			tx_ena <= '0';
			if rx_done = '1' then
				case rx_data(1 to 2) is
					when "00" => dbg_a <= not "0000";
					when "01" => dbg_a <= not "0001";
					when "02" => dbg_a <= not "0010";
					when "03" => dbg_a <= not "0011";
					when "04" => dbg_a <= not "0100";
					when "05" => dbg_a <= not "0101";
					when "06" => dbg_a <= not "0110";
					when "07" => dbg_a <= not "0111";
					when "08" => dbg_a <= not "1000";
					when "09" => dbg_a <= not "1001";
					when "10" => dbg_a <= not "1010";
					when "11" => dbg_a <= not "1011";
					when "12" => dbg_a <= not "1100";
					when "13" => dbg_a <= not "1101";
					when "14" => dbg_a <= not "1110";
					when "15" => dbg_a <= not "1111";
					when others => dbg_a <= not "0000";
				end case;
				case rx_len is
					when 1 => dbg_b <= not "0000";
					when 2 => dbg_b <= not "0001";
					when 3 => dbg_b <= not "0010";
					when 4 => dbg_b <= not "0011";
					when 5 => dbg_b <= not "0100";
					when 6 => dbg_b <= not "0101";
					when 7 => dbg_b <= not "0110";
					when 8 => dbg_b <= not "0111";
					when 9 => dbg_b <= not "1000";
					when 10 => dbg_b <= not "1001";
					when 11 => dbg_b <= not "1010";
					when 12 => dbg_b <= not "1011";
					when others => dbg_b <= not "0000";
				end case;
			end if;
		end if;

	end process;

end arch;
