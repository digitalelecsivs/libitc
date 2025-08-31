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
    tts_mo           : in unsigned(2 downto 0);
    tts_rst_n        : out std_logic;
    -- user logic
    ena     : in std_logic; -- start on enable rising edge
    busy    : out std_logic;
    txt     : in u8_arr_t(0 to txt_len_max - 1);
    txt_len : in integer range 0 to txt_len_max
  );
end tts;

architecture arch of tts is

  --------------------------------------------------------------------------
  -- 常數/型別
  --------------------------------------------------------------------------
  constant tts_addr : unsigned(6 downto 0) := "0100000"; -- 7-bit address

  type tts_state_t is (idle, send, send_stop, wait_speech);
  signal state : tts_state_t;

  --------------------------------------------------------------------------
  -- I2C 介面訊號
  --------------------------------------------------------------------------
  signal i2c_ena  : std_logic;
  signal i2c_busy : std_logic;
  signal i2c_in   : u8_t;

  -- 邊緣偵測
  signal start         : std_logic;
  signal i2c_accepted  : std_logic; -- i2c_busy 上升緣
  signal i2c_done      : std_logic; -- i2c_busy 下降緣
  signal tts_done      : std_logic; -- MO0 上升緣（語音完成）
  signal tts_accepted  : std_logic; -- MO0 下降緣（可視為開始被接受）

  -- 傳送計數（!!! 擴大到 txt_len_max + 2，避免上限溢出）
  signal txt_cnt : integer range 0 to txt_len_max + 2;

begin
  --------------------------------------------------------------------------
  -- 對外 reset 腳位直接跟系統 reset
  --------------------------------------------------------------------------
  tts_rst_n <= rst_n;

  --------------------------------------------------------------------------
  -- I2C master
  --------------------------------------------------------------------------
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
      cmd      => tts_addr & '0',  -- write
      data_in  => i2c_in,
      data_out => open
    );

  --------------------------------------------------------------------------
  -- 邊緣偵測：i2c_busy / 啟動 ena / MO0
  --------------------------------------------------------------------------
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

  edge_inst_mo0 : entity work.edge(arch)
    port map(
      clk     => clk,
      rst_n   => rst_n,
      sig_in  => tts_mo(0),
      rising  => tts_done,
      falling => tts_accepted
    );

  --------------------------------------------------------------------------
  -- 主狀態機
  --------------------------------------------------------------------------
  process (clk, rst_n) begin
    if rst_n = '0' then
      state    <= idle;
      busy     <= '0';       -- reset 後顯示閒置
      i2c_ena  <= '0';       -- 預設不啟動 I2C
      i2c_in   <= (others => '0');
      txt_cnt  <= 0;
    elsif rising_edge(clk) then
      case state is

        --------------------------------------------------------------------
        when idle =>
          busy <= '0';
          i2c_ena <= '0';    -- 確保在 idle 不會誤觸發
          txt_cnt <= 0;

          if start = '1' then
            -- 第 1 個 byte：發送 tts_set_mo 指令
            i2c_in  <= tts_set_mo;
            i2c_ena <= '1';         -- 拉高開始串流
            busy    <= '1';         -- 一開始就拉 busy
            state   <= send;
          end if;

        --------------------------------------------------------------------
        when send =>
          busy <= '1';

          -- 當上一顆 byte 完整傳完（busy 下降緣），決定下一顆要塞什麼
          if i2c_done = '1' then
            if txt_cnt = 0 then
              -- 第 2 顆：MO[2..0] = 110
              i2c_in <= x"06";
            elsif (txt_cnt >= 1) and (txt_cnt <= txt_len) then
              -- 文字資料（txt_cnt=1 對應 txt(0)）
              i2c_in <= txt(txt_cnt - 1);
            elsif txt_cnt = (txt_len + 1) then
              -- 倒數第 2 顆：再送一次 tts_set_mo
              i2c_in <= tts_set_mo;
            else
              -- 最後一顆：MO[2..0] = 111（觸發播放）
              i2c_in <= x"07";
            end if;

            -- 達成「送完最後一顆後」就準備停 I2C 串流
            if txt_cnt = (txt_len + 2) then
              txt_cnt <= 0;
              state   <= send_stop;     -- 下一拍等待最後一顆被 i2c 接受/完成
            else
              txt_cnt <= txt_cnt + 1;
            end if;
          end if;

          -- 注意：在 send 期間維持 i2c_ena='1'，讓介面持續吃資料

        --------------------------------------------------------------------
        when send_stop =>
          busy <= '1';

          -- 最後一顆被介面「接受」後，關閉 i2c_ena，避免再觸發下一傳輸
          if i2c_accepted = '1' then
            i2c_ena <= '0';
          end if;

          -- 等待最後一顆真正傳完（busy 下降緣），再去等語音播放完成
          if i2c_done = '1' then
            state <= wait_speech;
          end if;

        --------------------------------------------------------------------
        when wait_speech =>
          busy <= '1';

          -- 由 MO0 的上升緣判斷播放完成（依你的 edge_inst_mo0 設定）
          if tts_done = '1' then
            state <= idle;
          end if;

      end case;
    end if;
  end process;

end arch;
