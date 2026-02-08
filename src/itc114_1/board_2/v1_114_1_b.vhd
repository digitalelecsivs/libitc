library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;
use work.itc_lcd.all;

entity v1_114_1_b is
	port (
		clk     : in std_logic;
		rst_n   : in std_logic;
		key_row : in u4r_t;
		key_col : out u4r_t;
		dbg_a   : out u4r_t;
		--uart
		uart_rx : in std_logic; -- receive pin
		uart_tx : out std_logic -- transmit pin
	);
end v1_114_1_b;

architecture arch of v1_114_1_b is
	--key board
	signal pressed_r : std_logic;
	signal pressed_f : std_logic;
	signal pressed_i : std_logic;
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
			tx_mode => tx_mode, --是否移除stx 和 etx ('1'移除 '0' 保留)
			rx_busy => rx_busy, -- data reception in progress
			rx_data => rx_data, -- data received
			rx_len  => rx_len
		);
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed_i,
			key     => key
		);
	key_edge : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed_r,
			falling => pressed_f
		);
	-- key_col <= "0111" when CNT(11 downto 10) = "00" else
	-- "1011" when CNT(11 downto 10) = "01" else
	-- "1101" when CNT(11 downto 10) = "10" else
	-- "1110" when CNT(11 downto 10) = "11" else "0000";
	-- process (clk, rst_n)
	-- begin
	-- 	if rst_n = '0' then

	-- 	elsif rising_edge(clk) then
	-- 		CNT <= CNT + 1;
	-- 		if CNT(11 downto 10) = "00" then
	-- 			case key_row is
	-- 				when "0111" => key <= 0;
	-- 					dbg_a <= not "0000";
	-- 					pressed <= '1';
	-- 				when "1011" => key <= 1;
	-- 					dbg_a <= not "0001";
	-- 					pressed <= '1';
	-- 				when "1101" => key <= 2;
	-- 					dbg_a <= not "0010";
	-- 					pressed <= '1';
	-- 				when "1110" => key <= 3;
	-- 					dbg_a <= not "0011";
	-- 					pressed <= '1';
	-- 				when others => null;
	-- 					pressed <= '0';
	-- 			end case;
	-- 		elsif CNT(11 downto 10) = "01" then
	-- 			case key_row is
	-- 				when "0111" => key <= 4;
	-- 					dbg_a <= not "0100";
	-- 					pressed <= '1';
	-- 				when "1011" => key <= 5;
	-- 					dbg_a <= not "0101";
	-- 					pressed <= '1';
	-- 				when "1101" => key <= 6;
	-- 					dbg_a <= not "0110";
	-- 					pressed <= '1';
	-- 				when "1110" => key <= 7;
	-- 					dbg_a <= not "0111";
	-- 					pressed <= '1';
	-- 				when others => null;
	-- 					pressed <= '0';
	-- 			end case;
	-- 		elsif CNT(11 downto 10) = "10" then
	-- 			case key_row is
	-- 				when "0111" => key <= 8;
	-- 					dbg_a <= not "1000";
	-- 					pressed <= '1';
	-- 				when "1011" => key <= 9;
	-- 					dbg_a <= not "1001";
	-- 					pressed <= '1';
	-- 				when "1101" => key <= 10;
	-- 					dbg_a <= not "1010";
	-- 					pressed <= '1';
	-- 				when "1110" => key <= 11;
	-- 					dbg_a <= not "1011";
	-- 					pressed <= '1';
	-- 				when others => null;
	-- 					pressed <= '0';
	-- 			end case;
	-- 		elsif CNT(11 downto 10) = "11" then
	-- 			case key_row is
	-- 				when "0111" => key <= 12;
	-- 					dbg_a <= not "1100";
	-- 					pressed <= '1';
	-- 				when "1011" => key <= 13;
	-- 					dbg_a <= not "1101";
	-- 					pressed <= '1';
	-- 				when "1101" => key <= 14;
	-- 					dbg_a <= not "1110";
	-- 					pressed <= '1';
	-- 				when "1110" => key <= 15;
	-- 					dbg_a <= not "1111";
	-- 					pressed <= '1';
	-- 				when others => null;
	-- 					pressed <= '0';
	-- 			end case;
	-- 		end if;
	-- 	end if;
	-- end process;

	process (clk)
		variable mode : state := IDLE;
	begin
		if rst_n = '0' then
		elsif rising_edge(clk) then
			case mode is
				when IDLE =>
					if pressed_r = '1' then
						if tx_busy = '0' then
							case key is
								when 0 =>
									dbg_a <= not "0000";
									tx_data(1 to 2) <= "00";
								when 1 =>
									dbg_a <= not "0001";
									tx_data(1 to 2) <= "01";
								when 2 =>
									dbg_a <= not "0010";
									tx_data(1 to 2) <= "02";
								when 3 =>
									dbg_a <= not "0011";
									tx_data(1 to 2) <= "03";
								when 4 =>
									dbg_a <= not "0100";
									tx_data(1 to 2) <= "04";
								when 5 =>
									dbg_a <= not "0101";
									tx_data(1 to 2) <= "05";
								when 6 =>
									dbg_a <= not "0110";
									tx_data(1 to 2) <= "06";
								when 7 =>
									dbg_a <= not "0111";
									tx_data(1 to 2) <= "07";
								when 8 =>
									dbg_a <= not "1000";
									tx_data(1 to 2) <= "08";
								when 9 =>
									dbg_a <= not "1001";
									tx_data(1 to 2) <= "09";
								when 10 =>
									dbg_a <= not "1010";
									tx_data(1 to 2) <= "10";
								when 11 =>
									dbg_a <= not "1011";
									tx_data(1 to 2) <= "11";
								when 12 =>
									dbg_a <= not "1100";
									tx_data(1 to 2) <= "12";
								when 13 =>
									dbg_a <= not "1101";
									tx_data(1 to 2) <= "13";
								when 14 =>
									dbg_a <= not "1110";
									tx_data(1 to 2) <= "14";
								when 15 =>
									dbg_a <= not "1111";
									tx_data(1 to 2) <= "15";
							end case;
							tx_len <= 2;
							tx_mode <= '0';
							tx_ena <= '1';
							mode := SEND_PULSE;
						else
							tx_ena <= '0';
							mode := IDLE;
						end if;
					elsif pressed_f = '1'then
						if tx_busy = '0'then
							case key is
								when 0 =>
									dbg_a <= not "0000";
									tx_data(1 to 2) <= "00";
								when 1 =>
									dbg_a <= not "0001";
									tx_data(1 to 2) <= "01";
								when 2 =>
									dbg_a <= not "0010";
									tx_data(1 to 2) <= "02";
								when 3 =>
									dbg_a <= not "0011";
									tx_data(1 to 2) <= "03";
								when 4 =>
									dbg_a <= not "0100";
									tx_data(1 to 2) <= "04";
								when 5 =>
									dbg_a <= not "0101";
									tx_data(1 to 2) <= "05";
								when 6 =>
									dbg_a <= not "0110";
									tx_data(1 to 2) <= "06";
								when 7 =>
									dbg_a <= not "0111";
									tx_data(1 to 2) <= "07";
								when 8 =>
									dbg_a <= not "1000";
									tx_data(1 to 2) <= "08";
								when 9 =>
									dbg_a <= not "1001";
									tx_data(1 to 2) <= "09";
								when 10 =>
									dbg_a <= not "1010";
									tx_data(1 to 2) <= "10";
								when 11 =>
									dbg_a <= not "1011";
									tx_data(1 to 2) <= "11";
								when 12 =>
									dbg_a <= not "1100";
									tx_data(1 to 2) <= "12";
								when 13 =>
									dbg_a <= not "1101";
									tx_data(1 to 2) <= "13";
								when 14 =>
									dbg_a <= not "1110";
									tx_data(1 to 2) <= "14";
								when 15 =>
									dbg_a <= not "1111";
									tx_data(1 to 2) <= "15";
							end case;
							tx_len <= 2;
							tx_mode <= '0';
							tx_ena <= '1';
							mode := SEND_PULSE;
						else
							tx_ena <= '0';
							mode := IDLE;
						end if;
					end if;
				when SEND_PULSE =>
					tx_ena <= '0';
					mode := IDLE;
			end case;
		end if;
	end process;

end arch;
