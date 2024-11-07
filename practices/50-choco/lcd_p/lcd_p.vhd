library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;
use work.itc.all;
use work.itc_lcd.all;

entity lcd_p is
	port (
		clk   : in std_logic;
		rst_n : in std_logic;
		--seg
		seg_led, seg_com : out u8r_t;
		--sw
		sw : in u8r_t;
		--key
		key_row : in u4r_t;
		key_col : out u4r_t;
		--lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic;
		--tts
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		tts_rst_n        : out std_logic;
		-- mot
		mot_ch  : out u2r_t;
		mot_ena : out std_logic;
		--dot
		dot_red   : out u8r_t;
		dot_green : out u8r_t;
		dot_com   : out u8r_t
	);
end lcd_p;

architecture arch of lcd_p is
	signal x: integer range -127 to 128;
	signal y: integer range -159 to 160;
	signal font_start, font_busy,draw_done,state : std_logic;
	signal text_data : string(1 to 12):="            ";
	signal bg_color, pic_data_o,bg_color_t,bg_color_t2 : l_px_t;
	signal lcd_clear : std_logic:='1';
	signal lcd_con,clk_5: std_logic:='0';

	signal l_addr,shape_1_addr,O_addr,left_addr,pic_addr: l_addr_t;
	signal shape_1_data_o,O_data_o,left_data_o: std_logic_vector(23 downto 0);
	signal pic_col : l_px_t; -- can set pic color
	signal O_data, shape_1_data,left_data: l_px_t;

	signal text_color : l_px_arr_t(1 to 12):=(blue,blue,blue,blue,blue,blue,blue,blue,blue,blue,blue,blue);
	signal flash_mod, flash : std_logic;
	signal pressed_i, mode_s : std_logic;
	signal key_r,key_f, flag,clk1000: std_logic;
	signal key : i4_t;
	signal data_g, data_r : u8r_arr_t(0 to 7);
	signal timer_ena:std_logic;
	signal msec : i32_t;
	signal x_s,y_s:std_logic_vector(0 to 6);

begin
	shape_1_data <= unsigned(shape_1_data_o);
	O_data<=unsigned(O_data_o);
	left_data<=unsigned(left_data_o);
process(clk) begin
	data_g(7)(7)<=font_busy;
	data_g(6)(7)<=lcd_clear;
	if rst_n='0'then
		lcd_clear<='0';
		lcd_con<='0';
		bg_color<=white;
		font_start<='0';
		timer_ena<='0';
		x<=0;
		y<=0;
		state<='1';
	end if;
	if key_r='1' and key=0 then
		font_start<='1';
	elsif key_r='1' and key=1 then
		state<='0';
	elsif key_r='1' and key=2 then
		lcd_con<='0';
	end if;
	if state='1' then
		text_data<="1234asdf5678";
		x<=0;
		y<=60;
		if draw_done = '1' then
			font_start<='0';
		end if;
	elsif state='0' then
		lcd_con<='1';
		bg_color_t<= to_data(l_paste(l_addr, white, shape_1_data, (0, 0), 128, 160));
		bg_color_t2<=to_data(l_paste(l_addr, bg_color_t, O_data, (0, 0), 32, 32));
		-- bg_color<=to_data(l_paste(l_addr, white, shape_1_data, (0, 0), 128, 160));
		shape_1_addr <= to_addr(l_paste(l_addr, white, shape_1_data, (0, 0), 128, 160));
		-- bg_color <= to_data(l_paste(l_addr, bg_color_t, O_data, (0, 0), 32, 32));
		O_addr <= to_addr(l_paste(l_addr, bg_color_t, O_data, (0, 0), 32, 32));
		-- pic_data_o <= to_data(l_paste(l_addr, bg_color_t2, left_data, (0, 0), 16, 16));
		left_addr <= to_addr(l_paste(l_addr, bg_color_t2, left_data, (0, 0), 16, 16));
		pic_data_o <= (l_paste_txt(l_addr, white,"1234asdf5678", (0, 0), green));
		if draw_done = '1' then
			lcd_clear<='0';
		end if;
	end if;
	end process;

	O:entity work.O(syn)
	port map(
		address => std_logic_vector(to_unsigned(O_addr, 10)),
		clock   => clk,
		q       => O_data_o
	);
	left:entity work.left(syn)
	port map(
		address => std_logic_vector(to_unsigned(left_addr, 10)),
		clock   => clk,
		q       => left_data_o
	);
	rainbow: entity work.rainbow_image_128x160(syn)
	port map(
		address => std_logic_vector(to_unsigned(shape_1_addr, 14)),
		clock   => clk,
		q       => shape_1_data_o
	);
	lcd_mix_inst : entity work.lcd_mix(arch)
	port map(
		clk              => clk,
		rst_n            => rst_n,
		x                => x,
		y                => y,
		font_start       => font_start,
		font_busy        => font_busy,
		text_size        => 1,
		text_data        => text_data,
		text_count       => open,
		addr             => l_addr,
		text_color       => green,
		bg_color         => bg_color,
		text_color_array => text_color,
		clear            => lcd_clear,
		lcd_sclk         => lcd_sclk,
		lcd_mosi         => lcd_mosi,
		lcd_ss_n         => lcd_ss_n,
		lcd_dc           => lcd_dc,
		lcd_bl           => lcd_bl,
		lcd_rst_n        => lcd_rst_n,
		con              => lcd_con,--lcd_con,
		pic_addr         => pic_addr,
		pic_data         => pic_data_o
	);
	edge_lcd_draw_inst : entity work.edge(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			sig_in  => font_busy,
			rising  => open,
			falling => draw_done
		);
		clk_10_inst : entity work.clk(arch)
		generic map(
			freq => 1
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_5
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
	edge_key_inst : entity work.edge(arch)
		port map(
			clk     => clk1000,
			rst_n   => rst_n,
			sig_in  => pressed_i,
			rising  => key_r,
			falling => key_f
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
		timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => timer_ena, --當ena='0', msec=load
			load  => 0,     	--起始值
			msec  => msec       --毫秒數
		);
end arch;