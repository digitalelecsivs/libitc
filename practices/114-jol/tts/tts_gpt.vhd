library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.itc.all;

entity tts_gpt is
    port (
        clk, rst_n : in std_logic;
        sw      : in u8r_t;   -- 外部觸發
        tts_scl, tts_sda   : inout std_logic;
		tts_rst_n 			: out std_logic;
        dbg_a : out u8r_t
    );
end entity;

architecture rtl of tts_gpt is
   

    type state_t is (
        idle, wake, set_mo_cmd, set_mo_data,
        set_audio_cmd, set_audio_data,
        send_text, done
    );
    signal state : state_t := idle;

    signal ena    : std_logic := '0';
    signal cmd    : u8_t := (others => '0');
    signal din    : u8_t := (others => '0');
    signal dummy  : u8_t;
    signal iic_busy : std_logic;
    constant slave_addr : u8_t := x"40";  -- 7-bit=0100000 + W=0

    -- Big5 測試字串
    constant big5 : u8_arr_t(0 to 21) := (
        x"B9", x"73", x"A4", x"40", x"A4", x"47", x"A4", x"54",
        x"A5", x"7C", x"A4", x"AD", x"A4", x"BB", x"A4", x"43",
        x"A4", x"4B", x"A4", x"45", x"A4", x"51"
    );
    signal text_idx : integer range 0 to big5'length-1 := 0;

begin
	tts_rst_n <= rst_n;
    i2c_inst : entity work.i2c(arch)
        generic map(
				bus_freq => 400_000
			)
        port map (
            clk     => clk,
            rst_n   => rst_n,
            scl     => tts_scl,
            sda     => tts_sda,
            ena     => ena,
            busy    => iic_busy,
            cmd     => cmd,
            data_in => din,
            data_out => dummy
        );
        
        
dbg_a(0)<='0' when state=idle else '1';
dbg_a(1)<='0' when state=wake else '1';
dbg_a(2)<='0' when state=set_mo_cmd else '1';
dbg_a(3)<='0' when state=set_mo_data else '1';
dbg_a(4)<='0' when state=set_audio_cmd else '1';
dbg_a(5)<='0' when state=set_audio_data else '1';
dbg_a(6)<='0' when state=send_text else '1';
dbg_a(7)<='0' when state=done else '1';

    process(clk, rst_n)
    begin
        if rst_n = '0' then
            state <= idle;
            ena   <= '0';
            text_idx <= 0;
        elsif rising_edge(clk) then
            case state is
                when idle =>
                    ena <= '0';
                    text_idx <= 0;
                    if sw(0) = '1' then
                        -- 進入流程
                        cmd <= slave_addr;
                        din <= x"00";  -- 喚醒
                        ena <= '1';
                        state <= wake;
                    end if;

                when wake =>
                    if iic_busy='0' then 
                    ena <= '0';
                    state <= set_mo_cmd;
                    end if;
                when set_mo_cmd =>
                    if iic_busy='0' then 
                    cmd <= slave_addr;
                    din <= x"8A";  -- 設定 MO 命令
                    ena <= '1';
                    state <= set_mo_data;
                    end if;
                when set_mo_data =>
                    if iic_busy='0' then 
                    ena <= '0';
                    din <= x"00";  -- MO2~0 = 000
                    ena <= '1';
                    state <= set_audio_cmd;
                    end if;
                when set_audio_cmd =>
                    if iic_busy='0' then 
                    ena <= '0';
                    din <= x"8B";  -- 選通道控制命令
                    ena <= '1';
                    state <= set_audio_data;
                    end if;
                when set_audio_data =>
                    if iic_busy='0' then 
                    ena <= '0';
                    din <= x"04";  -- 開耳機輸出
                    ena <= '1';
                    state <= send_text;
                    end if;
                when send_text =>
                    if iic_busy='0' then 
                    ena <= '0';
                    if text_idx <= big5'high-1 then
                        din <= big5(text_idx);
                        ena <= '1';
                        text_idx <= text_idx + 1;
                    else
                        state <= done;
                    end if;
                    end if;
                when done =>
                    if iic_busy='0' then 
                    ena <= '0';
                    -- 等 sw(0) 放掉才回 idle
                    if sw(0) = '0' then
                        state <= idle;
                    end if;
                    end if;
            end case;
        end if;
    end process;
end rtl;
