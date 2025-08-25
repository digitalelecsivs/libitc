library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
use work.itc_lcd.all;
use ieee.std_logic_unsigned.all;

entity ox is
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
end ox;

architecture arch of ox is
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
	signal s9_data_o, o_data_o, x_data_o, block1_data_o : std_logic_vector(0 to 23);
	signal s9_data, o_data, x_data, pic_data, block1_data : l_px_t;
	signal l_addr, s9_addr, o_addr, x_addr, pic_addr, block1_addr : l_addr_t;
	signal clear, con : std_logic;
	signal text_data : string(1 to 12) := "            ";
	signal text_color_array : l_px_arr_t(1 to 12) := (blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue, blue);
	--user
	signal clk1000 : std_logic;
	signal ox : std_logic := '0';
	signal sel : integer range 1 to 9 := 1;
	type s is (background, block1);
	signal state : s := background;
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
	s9_data <= unsigned(s9_data_o);
	O_data <= unsigned(O_data_o);
	X_data <= unsigned(x_data_o);
	block1_data <= unsigned(block1_data_o);
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
	s9 : entity work.s9(syn)
		port map(
			address => std_logic_vector(to_unsigned(s9_addr, 14)),
			clock   => clk,
			q       => s9_data_o
		);
	O : entity work.O(syn)
		port map(
			address => std_logic_vector(to_unsigned(o_addr, 11)),
			clock   => clk,
			q       => o_data_o
		);

	x_pic : entity work.x(syn)
		port map(
			address => std_logic_vector(to_unsigned(x_addr, 11)),
			clock   => clk,
			q       => x_data_o
		);
	block_pic : entity work.block1(syn)
		port map(
			address => std_logic_vector(to_unsigned(block1_addr, 5)),
			clock   => clk,
			q       => block1_data_o
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
	process (clk)
		variable count : integer range 1 to 5;
	begin
		con <= '0';
		clear <= '1';
		bg_color <= pic(10);
		pic(0) <= to_data(l_paste(l_addr, white, s9_data, (0, 0), 128, 160));
		s9_addr <= to_addr(l_paste(l_addr, white, s9_data, (0, 0), 128, 160));
		pic(1) <= to_data(l_paste(l_addr, pic(0), block1_data, coord(sel), 10, 10));
		block1_addr <= to_addr(l_paste(l_addr, pic(0), block1_data, coord(sel), 10, 10));
		seg_data <= to_string((4 - (msec/1000)) * 1000 + sel * 100 + key, 99999999, 10, 8);
		for i in 1 to 9 loop
			if pic_sel(i) /= 3 then
				if pic_sel(i) = 1 then
					pic(i + 1) <= to_data(l_paste(l_addr, pic(i), x_data, coord_pic(i), 38, 50));
					x_addr <= to_addr(l_paste(l_addr, pic(i), x_data, coord_pic(i), 38, 50));
				else
					pic(i + 1) <= to_data(l_paste(l_addr, pic(i), o_data, coord_pic(i), 38, 50));
					o_addr <= to_addr(l_paste(l_addr, pic(i), o_data, coord_pic(i), 38, 50));
				end if;
			else
				pic(i + 1) <= pic(i);
			end if;
		end loop;
		if rising_edge(clk1000) then
			if pressed = '1' and timer_ena = '1' then
				timer_ena <= '0';
			elsif timer_ena = '0' then
				timer_ena <= '1';
			elsif msec = 4500 then
				timer_ena <= '0';
				mode <= timer;
				if pic_sel(sel) = 3 then
					ox <= not ox;
					if ox = '1' then
						pic_sel(sel) <= 1;
					else
						pic_sel(sel) <= 0;
					end if;
				end if;
			end if;
			if pressed = '1' and key = 0 then
				if sel > 3 then
					sel <= sel - 3;
				end if;
			end if;
			if pressed = '1' and key = 1 then
				if sel < 7 then
					sel <= sel + 3;
				end if;
			end if;
			if pressed = '1' and key = 2 then
				if sel /= 1 and sel /= 4 and sel /= 7 then
					sel <= sel - 1;
				end if;
			end if;
			if pressed = '1' and key = 3 then
				if sel /= 3 and sel /= 6 and sel /= 9 then
					sel <= sel + 1;
				end if;
			end if;
		end if;
	end process;
end arch;
