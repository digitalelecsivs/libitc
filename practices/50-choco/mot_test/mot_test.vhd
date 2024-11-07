library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;
use work.itc_lcd.all;
entity mot_test is
	port (
		clk, rst_n : in std_logic;

		--mot
		mot_ch  : out u2r_t     := "01";
		mot_ena : out std_logic := '1';
		sw      : in u8r_t;

		--seg
		seg_led, seg_com : out u8r_t
	);
end mot_test;

architecture arch of mot_test is
	--seg
	signal seg_data : string(1 to 8) := (others => ' ');
	signal dot : u8r_t := (others => '0');

	--timer
	signal msec, load : i32_t;
	signal timer_ena : std_logic;

	-- mot
	signal mot_dir : std_logic := '0';
	signal mot_speed : integer range 0 to 100;
begin
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
	mot_inst : entity work.mot(arch)
		port map(
			clk     => clk,
			rst_n   => rst_n,
			mot_ch  => mot_ch,
			mot_ena => mot_ena,
			dir     => mot_dir,
			speed   => mot_speed

		);
	timer_inst : entity work.timer(arch)
		port map(
			clk   => clk,
			rst_n => rst_n,
			ena   => timer_ena, --當ena='0', msec=load
			load  => load,      --起始值
			msec  => msec       --毫秒數
		);
	process (clk)
	begin
		if rising_edge(clk) then
			mot_dir <= sw(3);
			case sw(0 to 2) is
				when "000" => mot_speed <= 30;
				when "001" => mot_speed <= 50;
				when "010" => mot_speed <= 70;
				when "100" => mot_speed <= 100;
				when others => mot_speed <= 0;
			end case;
			-- timer_ena <= '1';
			-- if msec > 200 then
			-- 	timer_ena <= '0';
			-- 	mot_speed <= mot_speed + 1;
			-- 	seg_data <= to_string(mot_speed, 100, 10, 8);
			-- end if;
		end if;
	end process;
end arch;
