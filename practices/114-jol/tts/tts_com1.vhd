library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

entity tts_com1 is
	generic (
		txt_len_max : integer := 16 -- maximum length of text
	);
	port (
		-- system
		clk, rst_n : in std_logic;
		-- tts
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		tts_rst_n        : out std_logic;
		-- user logic
		-- ena  : in std_logic; -- start on enable rising edge
		-- busy : out std_logic;
		-- txt  : in u8_arr_t(0 to txt_len_max - 1)
		--key 
		key_row : in u4r_t;
		key_col : out u4r_t;
		dbg_a   : out u8r_t;
		dbg_b   : out u8r_t
	);
end tts_com1;

architecture arch of tts_com1 is
	constant tts_addr : unsigned(0 to 6) := "0100000";
	-- state 
	type state is (delay, awake, select_mode, set_mo0, set_mo1, set_mo2);
	signal mode : state := select_mode;
	-- i2c
	signal i2c_busy : std_logic;
	signal i2c_accepted : std_logic;
	signal i2c_done : std_logic;
	signal i2c_ena : std_logic;
	signal i2c_rw : std_logic; --0:write 1:read
	signal i2c_data_O : u8_t;
	signal i2c_data_I : u8_t;
	signal i2c_ack_err : std_logic;
	--timer
	signal msec : i32_t;
	signal load : i32_t := 0;
	signal timer_ena : std_logic;
	-- tts
	signal txt_buffer : u8_arr_t(0 to txt_len_max - 1);
	signal txt_len_buffer : integer range 0 to txt_len_max - 1 := 0;
	signal txt_mo0 : u8_arr_t(0 to 1) := (x"8A", x"01");
	signal txt_mo1 : u8_arr_t(0 to 1) := (x"8A", x"02");
	signal txt_mo2 : u8_arr_t(0 to 1) := (x"8A", x"04");
	signal txt_cnt : integer range 0 to 3 := 0;
	signal tts_begin : std_logic;
	signal tts_end : std_logic;
	--key
	signal pressed_i : std_logic;
	signal pressed : std_logic;
	signal key : i4_t;
	signal busy_cnt : i4_t;
	--reset
	constant reset_txt : u8_arr_t(0 to 1) := (x"8f", x"03");
begin
	Components : block begin
		i2c_com : entity work.i2c_master(arch)
			generic map(
				input_clk => 50_000_000, --input clock speed from user logic in Hz
				bus_clk   => 100_000     --speed the i2c bus (scl) will run at in Hz
			)
			port map(
				clk       => clk,                          --IN   	--system clock
				reset_n   => rst_n,                        --IN 		--active low reset
				ena       => i2c_ena,                      --IN 		--latch in command
				addr      => std_logic_vector(tts_addr),   --IN		--address of target slave
				rw        => i2c_rw,                       --IN		--'0' is write, '1' is read
				data_wr   => std_logic_vector(i2c_data_I), --IN		--data to write to slave
				busy      => i2c_busy,                     --OUT  	--indicates transaction in progress
				data_rd   => open,                         --OUT		--data read from slave
				ack_error => i2c_ack_err,                  --BUFFER 	--flag if improper acknowledge from slave
				sda       => tts_sda,                      --INOUT	--serial data output of i2c bus
				scl       => tts_scl                       --INOUT 
			);

		i2c_busy_edge : entity work.edge(arch)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => i2c_busy,
				rising  => i2c_accepted,
				falling => i2c_done
			);

		-- tts_ena_edge : entity work.edge(arch)
		-- 	port map(
		-- 		clk     => clk,
		-- 		rst_n   => rst_n,
		-- 		sig_in  => ena,
		-- 		rising  => tts_begin,
		-- 		falling => tts_end
		-- 	);

		-- tts_mo0_edge : entity work.edge(arch)
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
		key_edge : entity work.edge(arch)
			port map(
				clk     => clk,
				rst_n   => rst_n,
				sig_in  => pressed_i,
				rising  => pressed,
				falling => open
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
	end block Components;
	i2c_rw <= '0';
	tts_rst_n <= rst_n;
	-- tts component
	dbg_a(0) <= '1' when mode = select_mode else '0';
	dbg_a(1) <= '1' when mode = set_mo0 else '0';
	dbg_a(2) <= '1' when mode = set_mo1 else '0';
	dbg_a(3) <= '1' when mode = set_mo2 else '0';
	dbg_a(4) <= '1' when tts_mo(0) = '1' else '0';
	dbg_a(5) <= '1' when tts_mo(1) = '1' else '0';
	dbg_a(6) <= '1' when tts_mo(2) = '1' else '0';
	dbg_a(7) <= '1' when i2c_busy = '1' else '0';
	dbg_b(0 to 3) <= to_unsigned(busy_cnt, 4);
	dbg_b(4) <= '1' when i2c_ack_err = '1' else '0';
	dbg_b(5 to 7) <= (others => '0');
	process (clk, rst_n) begin
		if rst_n = '0' then
			mode <= delay;
			txt_cnt <= 0;
			i2c_ena <= '0';
		elsif rising_edge(clk) then
			case mode is
				when delay =>
					timer_ena <= '1';
					if msec > 300 then
						mode <= awake;
						timer_ena <= '0';
					end if;
				when awake =>
					i2c_ena <= '1';
					i2c_data_I <= null;

					if i2c_done = '1' then
						busy_cnt <= busy_cnt + 1;
						i2c_ena <= '0';
						mode <= select_mode;
					end if;
				
				when select_mode =>
					if pressed = '1' then
						case key is
							when 0 =>
								mode <= set_mo0;
								timer_ena <= '0';
								busy_cnt <= 0;
							when 1 =>
								mode <= set_mo1;
								timer_ena <= '0';
								busy_cnt <= 0;
							when 2 =>
								mode <= set_mo2;
								timer_ena <= '0';
								busy_cnt <= 0;
							when others => null;
						end case;
					end if;
				when set_mo0 =>
					i2c_ena <= '1';
					if txt_cnt <= txt_cnt'high and txt_cnt >= 0   then
						i2c_data_I <= txt_mo0(txt_cnt);
					end if;
					if i2c_done = '1'   then
						txt_cnt <= txt_cnt + 1;
					end if;
					if i2c_done = '1' then
						busy_cnt <= busy_cnt + 1;
					end if;
					if txt_cnt > 2 then
						txt_cnt <= 0;
						i2c_ena <= '0';
						mode <= select_mode;
					end if;
					
				when set_mo1 =>
					i2c_ena <= '1';
					if txt_cnt <= txt_cnt'high and txt_cnt >= 0 then
						i2c_data_I <= txt_mo1(txt_cnt);
					end if;
					if i2c_done = '1' then
						txt_cnt <= txt_cnt + 1;
					end if;
					if i2c_done = '1' then
						busy_cnt <= busy_cnt + 1;
					end if;
					if txt_cnt > 2 then
						txt_cnt <= 0;
						i2c_ena <= '0';
						mode <= select_mode;
					end if;
					
				when set_mo2 =>
					i2c_ena <= '1';
					if txt_cnt <= txt_cnt'high and txt_cnt >= 0   then
						i2c_data_I <= txt_mo2(txt_cnt);
					end if;
					if i2c_done = '1'    then
						txt_cnt <= txt_cnt + 1;
					end if;
					if i2c_done = '1' then
						busy_cnt <= busy_cnt + 1;
					end if;
					if txt_cnt > 2 then
						txt_cnt <= 0;
						i2c_ena <= '0';
						mode <= select_mode;
					end if;
					
			end case;

		end if;

	end process;
	-- tts_test.vhd
end arch;
