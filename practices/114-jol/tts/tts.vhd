library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity tts is
	generic (
		txt_len_max : integer := 16 -- maximum length of text
	);
	port (
		-- system
		clk, rst_n : in std_logic;
		-- tts
		tts_scl, tts_sda : inout std_logic;
		-- user logic
		ena     : in std_logic; -- start on enable rising edge
		busy    : out std_logic;
		txt     : in u8_arr_t(0 to txt_len_max - 1);
		txt_len : in integer range 0 to txt_len_max
	);
end tts;

architecture arch of tts is

	constant tts_addr : unsigned(6 downto 0) := "0100000";

	type tts_state_t is (idle, send, send_stop, wait_speech);
	signal state : tts_state_t;

	signal i2c_ena : std_logic;
	signal i2c_busy : std_logic;
	signal i2c_in : u8_t;

	signal start : std_logic;
	signal i2c_accepted : std_logic;
	signal i2c_done : std_logic;
	signal tts_done, tts_accepted : std_logic;

	signal txt_cnt : integer range 0 to txt_len_max - 1;

	--timer
	signal msec, load : i32_t;
	signal timer_ena : std_logic;

	signal tts_start_work : std_logic;
	--reset
	constant reset_txt : u8_arr_t(0 to 1) := (x"8f", x"03");
begin

	-- tts_rst_n <= rst_n;

	i2c_inst : entity work.i2c(arch)
		generic map(
			bus_freq => 100_000
		)
		port map(
			clk      => clk,
			rst_n    => rst_n,
			scl      => tts_scl,
			sda      => tts_sda,
			ena      => i2c_ena,
			busy     => i2c_busy,
			cmd      => tts_addr & '0',
			data_in  => i2c_in,
			data_out => open
		);

	edge_inst_i2c : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => i2c_busy,
			rising  => i2c_accepted,
			falling => i2c_done
		);

	edge_inst_ena : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => ena,
			rising  => start,
			falling => open
		);

	-- edge_inst_mo0 : entity work.edge(arch)
	-- 	port map(
	-- 		clk     => clk,
	-- 		rst_n   => rst_n,
	-- 		sig_in  => tts_mo(0),
	-- 		rising  => tts_done,
	-- 		falling => tts_accepted
	-- 	);
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => timer_ena, --當ena='0', msec=load
			load  => load,      --起始值
			msec  => msec       --毫秒數
		);
	process (clk, rst_n) begin
		if rst_n = '0' then
			txt_cnt <= 0;
			busy <= '0';
			state <= idle;
			timer_ena <= '1';
			tts_start_work <= '0';
		elsif rising_edge(clk) then
			if msec > 500 then
				timer_ena <= '0';
				tts_start_work <= '1';
			else tts_start_work <= '0';
			end if;
			if tts_start_work = '1' then
				case state is
					when idle =>
						if start = '1' then
							busy <= '1';
							i2c_in <= txt(txt_cnt);
							txt_cnt <= txt_cnt + 1;
							i2c_ena <= '1';
							state <= send;
						else
							busy <= '0';
						end if;
					when send =>
						i2c_in <= txt(txt_cnt);
						if txt_cnt < txt_len'high then
							txt_cnt <= txt_cnt + 1;
						else
							txt_cnt <= 0;
							state <= send_stop;
						end if;
						busy <= '1';
					when send_stop =>
						if i2c_done = '1' then -- last byte sent to interface
							i2c_ena <= '0';
							timer_ena <= '1';
							state <= wait_speech;
						end if;
						busy <= '1';
					when wait_speech =>
						if msec > 500 then
							timer_ena <= '0';
							busy <= '0';
							state <= idle;
						end if;
				end case;
			end if;
		end if;
	end process;

end arch;
