library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use work.itc.all;
entity dot_p is
	port (
		clk   : in std_logic;
		rst_n : in std_logic;

		key_row : in u2r_t;
		key_col : out u2r_t;

		seg_led : out u8r_t;
		seg_com : out u8r_t;

		dot_red   : out u8r_t;
		dot_green : out u8r_t;
		dot_com   : out u8r_t
	);
end dot_p;

architecture arch of dot_p is
	signal key : i4_t;
	signal seg_data : string(1 to 8);
	signal data_g, data_r : u8r_arr_t(0 to 7);
	signal pressed_i, mode_s : std_logic;
	signal key_r, flag : std_logic;
	signal clk1000, clk_2hz, clk_e2 : std_logic;
	type mode_t is (reset, sel, fuc1, fuc2, atk, end_game);
	signal mode : mode_t;
	signal fuc_s : std_logic;
	constant R : u8r_arr_t(0 to 7) := (x"41", x"42", x"44", x"48", x"7C", x"42", x"42", x"7C");
	constant E : u8r_arr_t(0 to 7) := (x"7E", x"40", x"40", x"7E", x"40", x"40", x"40", x"7E");
	constant S : u8r_arr_t(0 to 7) := (x"3C", x"42", x"02", x"04", x"38", x"40", x"42", x"3C");
	constant T : u8r_arr_t(0 to 7) := (x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"FF");

begin
	-- data_g <= (x"FF", x"FF", x"FF", x"FF", x"FF", x"FF", x"FF", x"FF");
	process (clk)
		variable count : std_logic_vector(0 to 13);
		variable pause : std_logic;
		variable x, y : integer range 0 to 8;
	begin
		if rising_edge(clk1000) then
			if rst_n = '0' or (key = 12 and key_r = '1') then
				mode <= reset;
				count := (others => '0');
			end if;
			case mode is
				when reset =>
					x := 1;
					mode_s <= '0';
					data_g <= (x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00");
					count := count + 1;
					if count <= 500 then
						seg_data <= "00000000";
						data_r <= R;
					elsif count <= 1000 then
						seg_data <= "11111111";
					elsif count <= 1500 then
						seg_data <= "22222222";
						data_r <= E;
					elsif count <= 2000 then
						seg_data <= "33333333";
					elsif count <= 2500 then
						seg_data <= "44444444";
						data_r <= S;
					elsif count <= 3000 then
						seg_data <= "55555555";
					elsif count <= 3500 then
						seg_data <= "66666666";
						data_r <= E;
					elsif count <= 4000 then
						seg_data <= "77777777";
					elsif count <= 4500 then
						seg_data <= "88888888";
						data_r <= T;
					elsif count <= 5000 then
						seg_data <= "99999999";
					elsif count <= 5500 then
						mode <= sel;
						data_r <= (x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00");
					end if;
				when sel =>
					if key_r = '1' and key = 13 then
						mode_s <= not mode_s;
					end if;
					if mode_s = '0'then
						seg_data <= "  F1    ";
						data_r <= (x"66", x"22", x"34", x"18", x"78", x"30", x"60", x"60");
					else
						seg_data <= "  F2    ";
						data_r <= (x"E0", x"40", x"00", x"00", x"00", x"00", x"DB", x"DB");
					end if;
					if key_r = '1' and key = 14 then
						if mode_s = '0' then
							pause := '0';
							mode <= fuc1;
							count := (others => '0');
							seg_data <= "  F1  OK";
						else
							mode <= fuc2;
							count := (others => '0');
							data_r <= (x"E0", x"40", x"00", x"00", x"00", x"00", x"DB", x"DB");
							seg_data <= "  F2  OK";
						end if;
					end if;
				when fuc1 =>
					if pause = '0' then
						count := count + 1;
						if count <= 250 then
							data_r <= (x"66", x"22", x"34", x"18", x"78", x"30", x"60", x"60");
						elsif count <= 500 then
							data_r <= (x"42", x"62", x"34", x"5A", x"7C", x"30", x"60", x"60");
						elsif count <= 750 then
							data_r <= (x"02", x"66", x"14", x"B2", x"7C", x"30", x"60", x"60");
						elsif count <= 1000 then
							data_r <= (x"02", x"C6", x"24", x"B0", x"64", x"78", x"C0", x"C0");
						elsif count <= 1250 then
							data_r <= (x"E2", x"26", x"3A", x"B4", x"78", x"60", x"C0", x"C0");
						elsif count <= 1500 then
							data_r <= (x"C4", x"4C", x"32", x"B4", x"78", x"60", x"C0", x"C0");
						elsif count <= 1750 then
							data_r <= (x"24", x"54", x"30", x"74", x"78", x"60", x"C0", x"C0");
						elsif count <= 2000 then
							data_r <= (x"04", x"1C", x"18", x"14", x"34", x"30", x"60", x"60");
						elsif count > 2000 then
							count := (others => '0');
						end if;
					end if;
					if key_r = '1' and key = 3 then
						mode <= sel;
					end if;
					if key_r = '1' and key = 15 then
						if pause = '0' then
							data_r <= (x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00");
							data_r <= (x"66", x"3c", x"18", x"5a", x"5a", x"3c", x"18", x"18");
							pause := '1';
						else
							data_r <= (x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00");
							pause := '0';
						end if;
					end if;
				when fuc2 =>
					if key_r = '1' and key = 8 then
						if data_r(0) /= x"E0" then
							x := x - 1;
							data_r(0) <= data_r(0) rol 1;
							data_r(1) <= data_r(1) rol 1;
						end if;
					end if;
					if key_r = '1' and key = 10 then
						if data_r(0) /= x"07" then
							x := x + 1;
							data_r(0) <= data_r(0) ror 1;
							data_r(1) <= data_r(1) ror 1;
						end if;
					end if;
					if key_r = '1' and key = 4 then
						flag <= '0';
						y := 2;
						data_r(y)(x) <= '1';
						mode <= atk;
					end if;
					for i in 0 to 7 loop
						case i is
							when 0 =>
								if data_r(6)(i) = '0'then
									data_r(7)(0) <= '0';
									data_r(6)(0) <= '0';
									data_r(7)(1) <= '0';
									data_r(6)(1) <= '0';
								end if;
							when 1 =>
								if data_r(6)(i) = '0'then
									data_r(7)(0) <= '0';
									data_r(6)(0) <= '0';
									data_r(7)(1) <= '0';
									data_r(6)(1) <= '0';
								end if;
							when 2 => null;
							when 3 =>
								if data_r(6)(i) = '0'then
									data_r(7)(3) <= '0';
									data_r(6)(4) <= '0';
									data_r(7)(4) <= '0';
									data_r(6)(3) <= '0';
								end if;
							when 4 =>
								if data_r(6)(i) = '0'then
									data_r(7)(3) <= '0';
									data_r(6)(4) <= '0';
									data_r(7)(4) <= '0';
									data_r(6)(3) <= '0';
								end if;
							when 5 => null;
							when 6 =>
								if data_r(6)(i) = '0'then
									data_r(7)(6) <= '0';
									data_r(6)(7) <= '0';
									data_r(7)(7) <= '0';
									data_r(6)(6) <= '0';
								end if;
							when 7 =>
								if data_r(6)(i) = '0'then
									data_r(7)(3) <= '0';
									data_r(6)(4) <= '0';
									data_r(7)(3) <= '0';
									data_r(6)(4) <= '0';
								end if;
						end case;
					end loop;
					if data_r(6) = x"00"then
						mode <= end_game;
						count := (others => '0');
					end if;
					if key_r = '1' and key = 3 then
						mode <= sel;
					end if;
				when atk =>

					flag <= '1';
					if clk_e2 = '1' then
						y := y + 1;
						if y /= 8 then
							data_r(y)(x) <= data_r(y - 1)(x) xor data_r(y)(x);
							if data_r(y - 1)(x) xor data_r(y)(x) then
								data_r(y - 1)(x) <= '0';
							end if;
						end if;
						if data_r(y)(x) = '1' and y = 5 then
							data_r(y)(x) <= '0';
						end if;
						if y /= 7 and y /= 8 then
							data_r(y - 1) <= x"00";
						end if;
						if not(data_r(y - 1)(x) xor data_r(y)(x)) then
							mode <= fuc2;
						end if;
						if y = 8 then
							mode <= fuc2;
							y := 2;
							data_r(7)(x) <= '0';
						end if;
						-- if y >= 7 then
						-- 	if data_r(6)(x) = '0' or y = 8 then
						--
						-- 	elsif data_r(y)(x) = '1' and y >= 7 then
						-- 		data_r(y)(x) <= '0';
						-- 	end if;
						-- end if;
					end if;
					if key_r = '1' and key = 3 then
						mode <= sel;
					end if;
				when end_game =>
					seg_data <= "GAMEOVER";
					count := count + 1;
					if count >= 2000 then
						mode <= sel;
						count := (others => '0');
						x := 1;
						y := 0;
					end if;
			end case;
		end if;
		if key_r = '1' then
			data_g(0)(0 to 3) <= (to_unsigned(key, 4));
		end if;
	end process;
	dot_inst : entity work.dot(arch)
		generic map(
			common_anode => '0'
		)
		port map(
			clk       => clk,
			rst_n     => rst_n,
			dot_red   => dot_red,
			dot_green => dot_green,
			dot_com   => dot_com,
			data_r    => data_g,
			data_g    => data_r
		);
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1000
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk1000
		);

	seg_inst : entity work.seg(arch)
		generic map(
			common_anode => '1'
		)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,
			seg_com => seg_com,
			data    => seg_data,
			dot => (others => '0')
		);
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
			clk     => clk1000,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => key_r,
			falling => open
		);
	clk_2hz_inst : entity work.clk(arch)
		generic map(
			freq => 2
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n and flag,
			clk_out => clk_2hz
		);
	edge_clk_2hz_inst : entity work.edge(arch)
		port map(
			clk     => clk1000,
			rst_n   => rst_n and flag,
			sig_in  => clk_2hz,
			rising  => open,
			falling => clk_e2
		);
end arch;
