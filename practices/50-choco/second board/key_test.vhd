library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use work.itc.all;

entity key_test is
	port (
		led   : out std_logic_vector(0 to 3);
		clk   : in std_logic;
		rst_n : in std_logic;

		key_row : in u2r_t;
		key_col : out u2r_t;

		uart_rx : in std_logic; -- receive pin
		uart_tx : out std_logic -- transmit pin
	);
end key_test;

architecture arch of key_test is
	--uart
	signal rx_start, rx_done : std_logic;
	signal tx_ena, tx_busy, rx_busy, rx_err : std_logic;
	signal tx_data, rx_data : string(1 to 8);
	signal tx_len, rx_len : integer range 1 to 8;
	--key
	signal key : i4_t;
	signal pressed_i : std_logic;
	signal key_r : std_logic;

begin
	key_inst : entity work.key_2x2_1(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,
			key_col => key_col,
			pressed => pressed_i,
			key     => key
		);
	edge_key_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => key_r,
			falling => open
		);
		edge_key_inst1 : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => rx_busy,
			rising  => open,
			falling => rx_done
		);
	uart_txt : entity work.uart_txt(arch)
		generic map(
			txt_len_max => 8,
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
			tx_len  => 8,
			rx_busy => rx_busy, -- data reception in progress
			rx_data => rx_data, -- data received
			rx_len  => rx_len
		);
	process (clk)begin
		if rising_edge(clk) then
			if rx_done = '1' then
				if rx_data = "11111111" then
					tx_ena <= '1';
					tx_data <= "success1";
					led <= "0000";
				end if;
			end if;
			if key_r = '1' then
				tx_ena <= '1';
				if key = 0 then
					led <= "0111";
					tx_data <= "00000000";
				end if;
				if key = 1 then
					tx_ena <= '1';
					led <= "1011";
					tx_data <= "10000000";
				end if;
				if key = 2 then
					tx_ena <= '1';
					led <= "1101";
					tx_data <= "20000000";
				end if;
				if key = 3 then
					tx_ena <= '1';
					led <= "1110";
					tx_data <= "30000000";
				end if;
			end if;
			if rx_done = '0' and key_r='0' then
				tx_ena <= '0';
			end if;
		end if;
	end process;
end arch;
