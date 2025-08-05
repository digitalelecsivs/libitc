library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
entity game is
	port (
		--sys
		clk, rst_n : in std_logic;
		--dot
		dot_red, dot_green, dot_com : out u8r_t;
		--keyboard
		key_row : in u4r_t;
		key_col : out u4r_t;
		--dbg_led
		dbg_b : out u8r_t;
		--segment
		seg_led, seg_com : out u8r_t
	);
end game;

architecture arch of game is
	type u8r_arr_t2 is array(0 to 14)of u8r_arr_t;
	constant data_dot : u8r_arr_t2 := (
	(X"41", X"42", X"44", X"48", X"7C", X"42", X"42", X"7C"), --R
		(X"7E", X"40", X"40", X"40", X"7E", X"40", X"40", X"7E"), --E
		(X"3C", X"42", X"02", X"04", X"38", X"40", X"42", X"3C"), --S
		(X"7E", X"40", X"40", X"40", X"7E", X"40", X"40", X"7E"), --E
		(X"18", X"18", X"18", X"18", X"18", X"18", X"18", X"FF"), --T
		(X"66", X"22", X"34", X"18", X"78", X"34", X"60", X"60"), --action1
		(X"42", X"62", X"34", X"5A", X"7C", X"30", X"60", X"60"), --action2
		(X"02", X"66", X"18", X"B2", X"7C", X"30", X"60", X"60"), --action3
		(X"02", X"C6", X"28", X"B0", X"64", X"78", X"C0", X"C0"), --action4  
		(X"E2", X"26", X"3A", X"B4", X"78", X"60", X"C0", X"C0"), --action5
		(X"C4", X"4C", X"32", X"B4", X"78", X"60", X"C0", X"C0"), --action6
		(X"28", X"58", X"30", X"74", X"78", X"60", X"C0", X"C0"), --action7
		(X"04", X"1C", X"14", X"18", X"38", X"30", X"60", X"60"), --action8
		(X"66", X"3C", X"18", X"5A", X"5A", X"3C", X"18", X"18"), --stop
		(X"00", X"00", X"00", X"00", X"00", X"00", X"00", X"00") --nothing
	);
	signal game_map : u8r_arr_t(0 to 7) := (X"00", X"00", X"00", X"00", X"00", X"00", X"DB", X"DB"); -- game_init;
	signal tank : u8r_arr_t(0 to 7) := (X"E0", X"40", X"00", X"00", X"00", X"00", X"00", X"00");

	signal pressed : std_logic;
	signal pressed_i : std_logic;
	signal key : i4_t;
	signal clk_cnt : std_logic;
	signal clk_cnt_i : std_logic;
	signal cnt_r : integer range 0 to 5 := 0;
	signal cnt_a : integer range 0 to 7 := 0;
	signal data_g : u8r_arr_t(0 to 7);
	signal data_r : u8r_arr_t(0 to 7);
	signal cnt_a_en : std_logic;
	type state is (Reset_mode, Sel_mode, Action_mode, game_mode, bullet_mode);
	signal mode : state := Reset_mode;
	signal sel_m : std_logic := '0';
	signal tank_coord : integer range 0 to 5;
	signal bullet_f : integer range 1 to 6;
	signal hit_f : std_logic;
	signal x_pos : integer range 0 to 2;
	signal y_pos : integer range 0 to 2;
	signal bullet_y : integer range 0 to (2 ** 3) := 2;
	signal clk_bullet : std_logic;
	signal clk_bullet_i : std_logic;
	signal seg : string(1 to 8) := (others => character'val(20));
	signal bullet_end : std_logic;
begin

	clk_inst1 : entity work.clk(arch)
		generic map(
			freq => 2
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_cnt_i
		);
	clk_inst2 : entity work.clk(arch)
		generic map(
			freq => 2
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_bullet_i
		);
	dot_inst : entity work.dot(arch)
		generic map(
			common_anode => '0'
		)
		port map(
			clk       => clk,
			rst_n     => rst_n,
			dot_red   => dot_red,   --腳位
			dot_green => dot_green, --腳位
			dot_com   => dot_com,   --腳位
			data_r    => data_r,    --紅色資料
			data_g    => data_g     --綠色資料
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
	edge_inst1 : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_cnt_i,
			rising  => clk_cnt,
			falling => open
		);
	edge_inst3 : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => clk_bullet_i,
			rising  => clk_bullet,
			falling => open
		);
	edge_inst2 : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => pressed,
			falling => open
		);
	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,    --腳位 a~g
			seg_com => seg_com,    --共同腳位
			data    => seg,        --七段資料 輸入要顯示字元即可,遮末則輸入空白
			dot => (others => '0') --小數點 1 亮
			--輸入資料ex: b"01000000" = x"70"  
			--seg_deg 度C
		);
	process (clk, rst_n) begin

		if rst_n = '0' then
			cnt_r <= 0;
			cnt_a <= 0;
			cnt_a_en <= '0';
			data_r <= (others => (others => '0'));
			data_g <= (others => (others => '0'));
			mode <= Reset_mode;
			tank_coord <= 0;
			game_map <= (X"00", X"00", X"00", X"00", X"00", X"00", X"DB", X"DB"); -- game_init;
			tank <= (X"E0", X"40", X"00", X"00", X"00", X"00", X"00", X"00");
			seg<= (others => character'val(20));
			bullet_y <= 2;
		elsif rising_edge(clk) then
			case mode is
				when Reset_mode =>

					if (cnt_r = cnt_r'high) then
						cnt_r <= 0;
						mode <= Sel_mode;
					elsif clk_cnt = '1' then
						cnt_r <= cnt_r + 1;
					end if;
					data_r <= data_dot(cnt_r);
					data_g <= data_dot(cnt_r);

				when Sel_mode =>
					if sel_m = '0' then
						seg(3 to 4) <= "oK";
						seg(7 to 8) <= character'val(10) & character'val(10);
						data_r <= data_dot(5);
						data_g <= data_dot(5);
					elsif sel_m = '1' then
						seg(3 to 4) <= character'val(10) & character'val(10);
						seg(7 to 8) <= "oK";

						for x in 0 to (2 ** 3) - 1 loop
							for y in 0 to (2 ** 3) - 1 loop
								data_r(x)(y) <= game_map(x)(y) or tank(x)(y);
								data_g(x)(y) <= game_map(x)(y) or tank(x)(y);
							end loop;
						end loop;
					end if;
					if pressed = '1' then
						case key is
							when 13 => sel_m <= not sel_m;
							when 14 =>
								if (sel_m = '0') then
									mode <= Action_mode;
								else mode <= game_mode;
								end if;
							when others => null;
						end case;
					end if;
				when Action_mode =>
					if cnt_a_en = '0' and clk_cnt = '1' then
						data_r <= data_dot(cnt_a + 5);
						data_g <= data_dot(cnt_a + 5);
						if (cnt_a = cnt_a'high) then
							cnt_a <= 0;
						end if;
						cnt_a <= cnt_a + 1;
					end if;

					if pressed = '1' then
						case key is
							when 15 => cnt_a_en <= not cnt_a_en;
							when 3 =>
								cnt_a <= 0;
								cnt_a_en <= '0';
								data_r <= (others => (others => '0'));
								data_g <= (others => (others => '0'));
								mode <= Sel_mode;
							when others => null;
						end case;
					end if;
				when game_mode =>
					if pressed = '1' then
						case key is
							when 8 => --left
								if tank_coord > 0 then
									tank(1) <= tank(1)(1 to 7) & '0';
									tank(0) <= tank(0)(1 to 7) & '0';

									tank_coord <= tank_coord - 1;
								end if;
							when 10 => --right
								if tank_coord < 5 then
									tank(1) <= '0' & tank(1)(0 to 6);
									tank(0) <= '0' & tank(0)(0 to 6);
									tank_coord <= tank_coord + 1;
								end if;
							when 9 => --bullet
								bullet_f <= tank_coord + 1;
								x_pos <= tank_coord - 1;
								mode <= bullet_mode;
							when 3 =>
								tank_coord <= 0;
								game_map <= (X"00", X"00", X"00", X"00", X"00", X"00", X"DB", X"DB"); -- game_init;
								tank <= (X"E0", X"40", X"00", X"00", X"00", X"00", X"00", X"00");
								mode <= Sel_mode;

							when others => null;
						end case;
					end if;
					data_r <= game_map;
					data_g <= game_map;
					for x in 0 to (2 ** 3) - 1 loop
						for y in 0 to (2 ** 1) - 1 loop
							data_r(y)(x) <= game_map(y)(x) or tank(y)(x);
							data_g(y)(x) <= game_map(y)(x) or tank(y)(x);
						end loop;
					end loop;

				when bullet_mode =>
					if clk_bullet = '1' then
						-- if clk_bullet = '1' then
						if bullet_y < 8 and bullet_y > 2 then
							data_r(bullet_y - 1)(bullet_f) <= game_map(bullet_y - 1)(bullet_f);
							data_g(bullet_y - 1)(bullet_f) <= game_map(bullet_y - 1)(bullet_f);
						end if;
						-- end if;
						if game_map(bullet_y)(bullet_f) = '1' then
							-- for x in x_pos to (x_pos + 2) loop
							-- 	for y in 6 to 7 loop
							-- 		game_map(y)(x) <= '0';
							-- 	end loop;
							-- end loop;
							game_map(bullet_y + 1)(bullet_f + 1) <= '0';
							game_map(bullet_y + 1)(bullet_f - 1) <= '0';
							game_map(bullet_y + 1)(bullet_f) <= '0';
							game_map(bullet_y)(bullet_f + 1) <= '0';
							game_map(bullet_y)(bullet_f - 1) <= '0';
							game_map(bullet_y)(bullet_f) <= '0';

							bullet_y <= 2;
							mode <= game_mode;
						else
							data_r(bullet_y)(bullet_f) <= '1';
							data_g(bullet_y)(bullet_f) <= '1';

							if bullet_y = 8 then
								bullet_y <= 2;
								mode <= game_mode; -- 飛出畫面結束
							else
								bullet_y <= bullet_y + 1;
							end if;
						end if;
					end if;
					if pressed = '1' then
						case key is
							when 3 => mode <= Sel_mode;
							when others => null;
						end case;
					end if;
			end case;
		end if;
	end process;

	dbg_b(0) <= sel_m;
	dbg_b(4 to 7) <= "0111" when mode <= Reset_mode else
	"1011" when mode <= Sel_mode else
	"1101" when mode <= Action_mode else
	"1110" when mode <= game_mode else "1111";
	dbg_b(1 to 3) <= "111";
end arch;
