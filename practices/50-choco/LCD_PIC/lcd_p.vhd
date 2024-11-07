library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
use work.itc_lcd.all;
use ieee.std_logic_unsigned.all;

entity lcd_p is
	port (
		clk, rst_n : in std_logic;
		--seg
		seg_led, seg_com : out u8r_t;

		-- key
		key_row : in u2r_t;
		key_col : out u2r_t;

		-- lcd，
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end lcd_p;

architecture arch of lcd_p is
	--seg
	signal seg_data : string(1 to 8) := (others => ' ');
	signal dot : u8r_t := (others => '0');
	--key
	signal pressed, pressed_i : std_logic;
	signal key : i4_t;
	--timer
	signal msec, load : i32_t;
	signal timer_ena : std_logic := '1';
	--lcd_draw
	signal f_data, bg_color, text_color : l_px_t;
	--signal addr : l_addr_t;
	signal data : string(1 to 12);
	signal font_start, font_busy, lcd_clear : std_logic;
	signal draw_done : std_logic;
	signal x, y : integer range 0 to 159;
	signal circle_data_o, circle_s_data_o, cstar_data_o, cstar_s_data_o, hexagon_data_o, hexagon_s_data_o, rectangle_data_o, rectangle_s_data_o, ridge_data_o, ridge_s_data_o, square_data_o, square_s_data_o, star_data_o, star_s_data_o, triangle_data_o, triangle_s_data_o, x_data_o, x_s_data_o : std_logic_vector(0 to 23);
	signal pic_data, circle_data, circle_s_data, cstar_data, cstar_s_data, hexagon_data, hexagon_s_data, rectangle_data, rectangle_s_data, ridge_data, ridge_s_data, square_data, square_s_data, star_data, star_s_data, triangle_data, triangle_s_data, x_data, x_s_data : l_px_t;
	signal pic_addr, l_addr, circle_addr, circle_s_addr, cstar_addr, cstar_s_addr, hexagon_addr, hexagon_s_addr, rectangle_addr, rectangle_s_addr, ridge_addr, ridge_s_addr, square_addr, square_s_addr, star_addr, star_s_addr, triangle_addr, triangle_s_addr, x_addr, x_s_addr : l_addr_t;
	signal clear, con : std_logic;
	signal text_data : string(1 to 12) := "            ";
	signal text_color_array : l_px_arr_t(1 to 12) := (blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue);
	--user
	signal clk1000 : std_logic;
	signal ox : std_logic := '0';
	signal sel : integer range 1 to 9 := 1;
	type s is (background, block1);
	signal state, flag : std_logic;
	type picture is array (0 to 10) of l_px_t;
	type picture_buffer is array(1 to 9) of integer range 1 to 3;
	signal pic : picture;
	signal pic_sel : picture_buffer := (3, 3, 3, 3, 3, 3, 3, 3, 3);
	type inter is array (1 to 9) of l_coord_t;
	constant coord : inter := ((20, 15), (20, 60), (20, 105), (75, 15), (75, 60), (75, 105), (130, 15), (130, 60), (130, 105));
	constant coord_pic : inter := ((0, 0), (0, 43), (0, 89), (55, 0), (55, 43), (55, 89), (105, 0), (105, 43), (105, 89));
	type draw is (timer, start);
	signal mode : draw;
begin

	circle_data <= unsigned(circle_data_o);
	circle_s_data <= unsigned(circle_s_data_o);
	cstar_data <= unsigned(cstar_data_o);
	cstar_s_data <= unsigned(cstar_s_data_o);
	hexagon_data <= unsigned(hexagon_data_o);
	hexagon_s_data <= unsigned(hexagon_s_data_o);
	rectangle_data <= unsigned(rectangle_data_o);
	rectangle_s_data <= unsigned(rectangle_s_data_o);
	ridge_data <= unsigned(ridge_data_o);
	ridge_s_data <= unsigned(ridge_s_data_o);
	square_data <= unsigned(square_data_o);
	square_s_data <= unsigned(square_s_data_o);
	star_data <= unsigned(star_data_o);
	star_s_data <= unsigned(star_s_data_o);
	triangle_data <= unsigned(triangle_data_o);
	triangle_s_data <= unsigned(triangle_s_data_o);
	x_data <= unsigned(x_data_o);
	x_s_data <= unsigned(x_s_data_o);
	seg_inst : entity work.seg(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			seg_led => seg_led,  --腳位 a~g
			seg_com => seg_com,  --共同腳位
			data    => seg_data, --七段資料 輸入要顯示字元即可,遮末則輸入空白
			dot     => dot       --小數點 1 亮
			--輸入資料ex: b"01000000" = x"70"
			--seg_deg 度C
		);
	circle1 : entity work.circle(syn)
		port map(
			address => std_logic_vector(to_unsigned(circle_addr, 10)),
			clock   => clk,
			q       => circle_data_o
		);
	circle_s1 : entity work.circle_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(circle_s_addr, 10)),
			clock   => clk,
			q       => circle_s_data_o
		);
	cstar1 : entity work.cstar(syn)
		port map(
			address => std_logic_vector(to_unsigned(cstar_addr, 10)),
			clock   => clk,
			q       => cstar_data_o
		);
	cstar_s1 : entity work.cstar_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(cstar_s_addr, 10)),
			clock   => clk,
			q       => cstar_s_data_o
		);
	hexagon1 : entity work.hexagon(syn)
		port map(
			address => std_logic_vector(to_unsigned(hexagon_addr, 10)),
			clock   => clk,
			q       => hexagon_data_o
		);
	hexagon_s1 : entity work.hexagon_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(hexagon_s_addr, 10)),
			clock   => clk,
			q       => hexagon_s_data_o
		);
	rectangle1 : entity work.rectangle(syn)
		port map(
			address => std_logic_vector(to_unsigned(rectangle_addr, 10)),
			clock   => clk,
			q       => rectangle_data_o
		);
	rectangle_s1 : entity work.rectangle_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(rectangle_s_addr, 10)),
			clock   => clk,
			q       => rectangle_s_data_o
		);
	ridge1 : entity work.ridge(syn)
		port map(
			address => std_logic_vector(to_unsigned(ridge_addr, 10)),
			clock   => clk,
			q       => ridge_data_o
		);
	ridge_s1 : entity work.ridge_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(ridge_s_addr, 10)),
			clock   => clk,
			q       => ridge_s_data_o
		);
	square1 : entity work.square(syn)
		port map(
			address => std_logic_vector(to_unsigned(square_addr, 10)),
			clock   => clk,
			q       => square_data_o
		);
	square_s1 : entity work.square_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(square_s_addr, 10)),
			clock   => clk,
			q       => square_s_data_o
		);
	star1 : entity work.star(syn)
		port map(
			address => std_logic_vector(to_unsigned(star_addr, 10)),
			clock   => clk,
			q       => star_data_o
		);
	star_s1 : entity work.star_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(star_s_addr, 10)),
			clock   => clk,
			q       => star_s_data_o
		);
	triangle1 : entity work.triangle(syn)
		port map(
			address => std_logic_vector(to_unsigned(triangle_addr, 10)),
			clock   => clk,
			q       => triangle_data_o
		);
	triangle_s1 : entity work.triangle_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(triangle_s_addr, 10)),
			clock   => clk,
			q       => triangle_s_data_o
		);
	x1 : entity work.x(syn)
		port map(
			address => std_logic_vector(to_unsigned(x_addr, 10)),
			clock   => clk,
			q       => x_data_o
		);
	x_s1 : entity work.x_s(syn)
		port map(
			address => std_logic_vector(to_unsigned(x_s_addr, 10)),
			clock   => clk,
			q       => x_s_data_o
		);
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1_000 --頻率
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk1000 --輸出
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
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => timer_ena, --當ena='0', msec=load
			load  => 0,         --起始值
			msec  => msec       --毫秒數
		);
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk1000, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => pressed_i, --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => pressed,   --正緣 '1'觸發
			falling => open       --負緣 open=開路
		);
	lcd_mix_inst : entity work.lcd_mix(arch)
		port map(
			clk              => clk,
			rst_n            => rst_n,
			x                => x,                -- 文字x軸
			y                => y,                -- 文字y軸
			font_start       => font_start,       -- 文字更新(取正緣)
			font_busy        => font_busy,        -- 當畫面正在更新時，font_busy='1'
			text_size        => 1,                -- 字體大小
			text_data        => text_data,        -- 文字資料
			addr             => l_addr,           -- 偵錯用
			text_color       => text_color,       -- 字體顏色(只能改單行)(若要使用需改gen_font.vhd(有註記))(若沒用到隨便填一顏色即可)
			bg_color         => bg_color,         -- 背景顏色 (背景顏色更改時，con為'0'，clear為'1')
			text_color_array => text_color_array, -- 字體顏色(同一行依位元改變)(text_color_array:l_px_arr_t(1 to 12);)
			clear            => clear,            -- '1' 時清除
			lcd_sclk         => lcd_sclk,         -- 腳位
			lcd_mosi         => lcd_mosi,         -- 腳位
			lcd_ss_n         => lcd_ss_n,         -- 腳位
			lcd_dc           => lcd_dc,           -- 腳位
			lcd_bl           => lcd_bl,           -- 腳位
			lcd_rst_n        => lcd_rst_n,        -- 腳位
			con              => con,              -- 選擇文字或圖片
			pic_addr         => pic_addr,         -- 圖片addr
			pic_data         => pic_data          -- 圖片資料
		);
	process (clk)
		variable count : integer range 1 to 5;
	begin
		if rst_n = '0'then
			timer_ena <= '0';
		elsif rising_edge(clk) then
			seg_data <= to_string((10 - (msec/1000)) * 1000 + sel * 100 + key, 99999999, 10, 8);
			timer_ena <= '1';
			con <= '0';
			clear <= '1';
			state <= '0';
			bg_color <= pic(8);
			-- if msec < 4000 then
			-- 	flag <= '0';
			-- end if;
			if msec = 0 then
				flag <= '1';
			end if;
			if state = '0' and flag = '1' then
				if msec >= 0 then
					pic(0) <= to_data(l_paste(l_addr, white, circle_data, coord_pic(1), 32, 32));
					circle_addr <= to_addr(l_paste(l_addr, white, circle_data, coord_pic(1), 32, 32));
				end if;
				if msec >= 500 then
					pic(1) <= to_data(l_paste(l_addr, pic(0), triangle_data, coord_pic(2), 32, 32));
					triangle_addr <= to_addr(l_paste(l_addr, pic(0), triangle_data, coord_pic(2), 32, 32));
				else
					pic(1) <= pic(0);
				end if;
				if msec >= 1000 then
					pic(2) <= to_data(l_paste(l_addr, pic(1), square_data, coord_pic(3), 32, 32));
					square_addr <= to_addr(l_paste(l_addr, pic(1), square_data, coord_pic(3), 32, 32));
				else
					pic(2) <= pic(1);
				end if;
				if msec >= 1500 then
					pic(3) <= to_data(l_paste(l_addr, pic(2), rectangle_data, coord_pic(4), 32, 32));
					rectangle_addr <= to_addr(l_paste(l_addr, pic(2), rectangle_data, coord_pic(4), 32, 32));
				else
					pic(3) <= pic(2);
				end if;
				if msec >= 2000 then
					pic(4) <= to_data(l_paste(l_addr, pic(3), x_data, coord_pic(5), 32, 32));
					x_addr <= to_addr(l_paste(l_addr, pic(3), x_data, coord_pic(5), 32, 32));
				else
					pic(4) <= pic(3);
				end if;
				if msec >= 2500 then
					pic(5) <= to_data(l_paste(l_addr, pic(4), cstar_data, coord_pic(6), 32, 32));
					cstar_addr <= to_addr(l_paste(l_addr, pic(4), cstar_data, coord_pic(6), 32, 32));
				else
					pic(5) <= pic(4);
				end if;
				if msec >= 3000 then
					pic(6) <= to_data(l_paste(l_addr, pic(5), star_data, coord_pic(7), 32, 32));
					star_addr <= to_addr(l_paste(l_addr, pic(5), star_data, coord_pic(7), 32, 32));
				else
					pic(6) <= pic(5);
				end if;
				if msec >= 3500 then
					pic(7) <= to_data(l_paste(l_addr, pic(6), ridge_data, coord_pic(8), 32, 32));
					ridge_addr <= to_addr(l_paste(l_addr, pic(6), ridge_data, coord_pic(8), 32, 32));
				else
					pic(7) <= pic(6);
				end if;
				if msec >= 4000 then
					pic(8) <= to_data(l_paste(l_addr, pic(7), hexagon_data, coord_pic(9), 32, 32));
					hexagon_addr <= to_addr(l_paste(l_addr, pic(7), hexagon_data, coord_pic(9), 32, 32));
				else
					pic(8) <= pic(7);
				end if;
				if msec >= 4500 then
					pic(0) <= to_data(l_paste(l_addr, white, circle_s_data, coord_pic(1), 32, 32));
					circle_s_addr <= to_addr(l_paste(l_addr, white, circle_s_data, coord_pic(1), 32, 32));
				end if;
				if msec >= 5000 then
					pic(1) <= to_data(l_paste(l_addr, pic(0), triangle_s_data, coord_pic(2), 32, 32));
					triangle_s_addr <= to_addr(l_paste(l_addr, pic(0), triangle_s_data, coord_pic(2), 32, 32));
				end if;
				if msec >= 6000 then
					pic(2) <= to_data(l_paste(l_addr, pic(1), square_s_data, coord_pic(3), 32, 32));
					square_s_addr <= to_addr(l_paste(l_addr, pic(1), square_s_data, coord_pic(3), 32, 32));
				end if;
				if msec >= 6500 then
					pic(3) <= to_data(l_paste(l_addr, pic(2), rectangle_s_data, coord_pic(4), 32, 32));
					rectangle_s_addr <= to_addr(l_paste(l_addr, pic(2), rectangle_s_data, coord_pic(4), 32, 32));
				end if;
				if msec >= 7000 then
					pic(4) <= to_data(l_paste(l_addr, pic(3), x_s_data, coord_pic(5), 32, 32));
					x_s_addr <= to_addr(l_paste(l_addr, pic(3), x_s_data, coord_pic(5), 32, 32));
				end if;
				if msec >= 7500 then
					pic(5) <= to_data(l_paste(l_addr, pic(4), cstar_s_data, coord_pic(6), 32, 32));
					cstar_s_addr <= to_addr(l_paste(l_addr, pic(4), cstar_s_data, coord_pic(6), 32, 32));
				end if;
				if msec >= 8000 then
					pic(6) <= to_data(l_paste(l_addr, pic(5), star_s_data, coord_pic(7), 32, 32));
					star_s_addr <= to_addr(l_paste(l_addr, pic(5), star_s_data, coord_pic(7), 32, 32));
				end if;
				if msec >= 8500 then
					pic(7) <= to_data(l_paste(l_addr, pic(6), ridge_s_data, coord_pic(8), 32, 32));
					ridge_s_addr <= to_addr(l_paste(l_addr, pic(6), ridge_s_data, coord_pic(8), 32, 32));
				end if;
				if msec >= 9000 then
					pic(8) <= to_data(l_paste(l_addr, pic(7), hexagon_s_data, coord_pic(9), 32, 32));
					hexagon_s_addr <= to_addr(l_paste(l_addr, pic(7), hexagon_s_data, coord_pic(9), 32, 32));
				end if;
				if msec >= 9500 then
					state <= '1';
					timer_ena <= '0';
					flag <= '0';
				end if;
				-- elsif state = '1' and flag = '1' then
				-- 	if msec >= 0 then
				-- 		pic(0) <= to_data(l_paste(l_addr, white, circle_data, coord_pic(1), 32, 32));
				-- 		circle_addr <= to_addr(l_paste(l_addr, white, circle_data, coord_pic(1), 32, 32));
				-- 	end if;
				-- 	if msec >= 500 then
				-- 		pic(1) <= to_data(l_paste(l_addr, pic(0), triangle_data, coord_pic(2), 32, 32));
				-- 		triangle_addr <= to_addr(l_paste(l_addr, pic(0), triangle_data, coord_pic(2), 32, 32));
				-- 	else
				-- 		pic(1) <= pic(0);
				-- 	end if;
				-- 	if msec >= 1000 then
				-- 		pic(2) <= to_data(l_paste(l_addr, pic(1), square_data, coord_pic(3), 32, 32));
				-- 		square_addr <= to_addr(l_paste(l_addr, pic(1), square_data, coord_pic(3), 32, 32));
				-- 	else
				-- 		pic(2) <= pic(1);
				-- 	end if;
				-- 	if msec >= 1500 then
				-- 		pic(3) <= to_data(l_paste(l_addr, pic(2), rectangle_data, coord_pic(4), 32, 32));
				-- 		rectangle_addr <= to_addr(l_paste(l_addr, pic(2), rectangle_data, coord_pic(4), 32, 32));
				-- 	else
				-- 		pic(3) <= pic(2);
				-- 	end if;
				-- 	if msec >= 2000 then
				-- 		pic(4) <= to_data(l_paste(l_addr, pic(3), x_data, coord_pic(5), 32, 32));
				-- 		x_addr <= to_addr(l_paste(l_addr, pic(3), x_data, coord_pic(5), 32, 32));
				-- 	else
				-- 		pic(4) <= pic(3);
				-- 	end if;
				-- 	if msec >= 2500 then
				-- 		pic(5) <= to_data(l_paste(l_addr, pic(4), cstar_data, coord_pic(6), 32, 32));
				-- 		cstar_addr <= to_addr(l_paste(l_addr, pic(4), cstar_data, coord_pic(6), 32, 32));
				-- 	else
				-- 		pic(5) <= pic(4);
				-- 	end if;
				-- 	if msec >= 3000 then
				-- 		pic(6) <= to_data(l_paste(l_addr, pic(5), star_data, coord_pic(7), 32, 32));
				-- 		star_addr <= to_addr(l_paste(l_addr, pic(5), star_data, coord_pic(7), 32, 32));
				-- 	else
				-- 		pic(6) <= pic(5);
				-- 	end if;
				-- 	if msec >= 3500 then
				-- 		pic(7) <= to_data(l_paste(l_addr, pic(6), ridge_data, coord_pic(8), 32, 32));
				-- 		ridge_addr <= to_addr(l_paste(l_addr, pic(6), ridge_data, coord_pic(8), 32, 32));
				-- 	else
				-- 		pic(7) <= pic(6);
				-- 	end if;
				-- 	if msec >= 4000 then
				-- 		pic(8) <= to_data(l_paste(l_addr, pic(7), hexagon_data, coord_pic(9), 32, 32));
				-- 		hexagon_addr <= to_addr(l_paste(l_addr, pic(7), hexagon_data, coord_pic(9), 32, 32));
				-- 	else
				-- 		pic(8) <= pic(7);
				-- 	end if;

			end if;
		end if;
	end process;
end arch;
