library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
use work.itc_lcd.all;
entity test is
	port (
		clk, rst_n : in std_logic;

		-- sw
		sw : in u8r_t;

		--led(r g y)
		led_r, led_g, led_y : out std_logic;

		-- dht
		dht_data : inout std_logic;

		--seg
		seg_led, seg_com : out u8r_t;

		-- key
		key_row : in u4r_t;
		key_col : out u4r_t;

		--8*8 dot led
		dot_red, dot_green, dot_com : out u8r_t;

		-- tsl
		tsl_scl, tsl_sda : inout std_logic;

		-- tts
		tts_scl, tts_sda : inout std_logic;
		tts_mo           : in unsigned(2 downto 0);
		dbg_b            : out u8r_t;
		tts_rst_n        : out std_logic;

		--buzzer
		buz : out std_logic; --'1' 叫  '0' 不叫

		--uart
		uart_rx : in std_logic;  -- receive pin
		uart_tx : out std_logic; -- transmit pin

		-- lcd
		lcd_sclk, lcd_mosi, lcd_ss_n, lcd_dc, lcd_bl, lcd_rst_n : out std_logic
	);
end test;

architecture arch of test is
	signal buz_ena, buz_flag : std_logic;
	signal buz_busy, buz_done : std_logic;

	--seg
	signal seg_data : string(1 to 8) := (others => ' ');
	signal dot : u8r_t := (others => '0');

	--key
	signal pressed, pressed_i : std_logic;
	signal key : i4_t;

	--dht11
	signal temp_int, hum_int : integer range 0 to 99;

	--tsl
	signal lux : i16_t;

	--f(1khz)
	signal msec, load : i32_t;
	signal timer_ena : std_logic;

	--lcd
	signal x : integer range -127 to 127;
	signal y : integer range -159 to 159;
	signal l_addr : l_addr_t;
	signal font_start, font_busy, draw_done : std_logic;
	signal text_data : string(1 to 12);
	signal text_color : l_px_arr_t(1 to 12);
	signal lcd_clear : std_logic;
	signal bg_color : l_px_t;
	signal lcd_con : std_logic;
	-- signal pic_addr : l_addr_t;
	-- signal pic_data : l_px_t;
	constant lcd_color1 : l_px_arr_t(1 to 4) := (white, black, black, red);
	constant lcd_color2 : l_px_arr_t(1 to 4) := (white, black, black, black);

	--8*8 dot led
	signal data_g, data_r : u8r_arr_t(0 to 7);

	--tts
	signal tts_ena : std_logic;
	signal busy : std_logic;
	constant max_len : integer := 100;
	signal txt : u8_arr_t(0 to max_len - 1);
	signal len : integer range 0 to max_len;
	signal tts_done : std_logic;
	type tts_mode_t is (idle, tts_play, stop);
	signal tts_mode : tts_mode_t;

	--uart
	signal tx_data, rx_data : u8_t := x"00";
	signal rx_start, rx_done : std_logic;
	signal tx_ena, tx_busy, rx_busy, rx_err : std_logic;

	--clk
	signal clk_e1 : std_logic;
	signal count : integer;
begin
	clk_inst : entity work.clk(arch)
		generic map(
			freq => 1 --頻率
		)
		port map(
			clk_in  => clk,
			rst_n   => rst_n,
			clk_out => clk_e1 --輸出
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
	key_inst : entity work.key(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			key_row => key_row,   --腳位
			key_col => key_col,   --腳位
			pressed => pressed_i, --pressed='1' 代表按住
			key     => key        --key=0 代表按下 key 1	key=1 代表按下 key 2...........
		);
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => timer_ena, --當ena='0', msec=load
			load  => load,      --起始值
			msec  => msec       --毫秒數
		);
	edge_inst : entity work.edge(arch)
		port map(
			clk     => clk, --直接給主程式除頻後頻率
			rst_n   => rst_n,
			sig_in  => pressed_i, --輸入訊號(通常用在 4*4 keypad或計數)
			rising  => pressed,   --正緣 '1'觸發
			falling => open       --負緣 open=開路
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
			con              => lcd_con,
			pic_addr         => open,
			pic_data         => white,
			lcd_sclk         => lcd_sclk,
			lcd_mosi         => lcd_mosi,
			lcd_ss_n         => lcd_ss_n,
			lcd_dc           => lcd_dc,
			lcd_bl           => lcd_bl,
			lcd_rst_n        => lcd_rst_n
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

	tts_inst : entity work.tts(arch)
		generic map(
			txt_len_max => max_len
		)
		port map(
			clk       => clk,
			rst_n     => rst_n,
			tts_scl   => tts_scl,   --腳位
			tts_sda   => tts_sda,   --腳位
			tts_mo    => tts_mo,    --腳位
			tts_rst_n => tts_rst_n, --腳位
			ena       => tts_ena,   --enable 1致能
			busy      => busy,      --播報時busy='1'
			txt       => txt,       --data(編碼產生=>tool=>tts.py=>compile=>輸入數目=>輸入名字=>輸入播報內容)
			txt_len   => len        --
		);
	process (clk, rst_n)
	begin
		if rst_n = '0' then
			data_g <= (x"ff", x"00", x"00", x"00", x"00", x"00", x"00", x"00");
			data_r <= (x"ff", x"00", x"00", x"00", x"00", x"00", x"00", x"ff");
		elsif rising_edge(clk) then
			if clk_e1 = '1' then
				if count /= 7 then
					data_g(count + 1) <= data_g(count);
					data_r(count + 1) <= data_g(count);
					count <= count + 1;
				else
					data_g(0) <= data_g(7);
					data_r(0) <= data_g(7);
					count <= 0;
				end if;
			end if;
		end if;
	end process;
end arch;
