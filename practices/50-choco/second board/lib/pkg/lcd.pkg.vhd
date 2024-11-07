library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.itc.all;

package itc_lcd is
	constant l_width : integer := 128;
	constant l_height : integer := 160;
	constant l_depth : integer := 24;
	constant l_px_cnt : integer := l_width * l_height;
	constant l_addr_width : integer := log(2, l_px_cnt);

	-- pixel type, can represent memory data or color
	subtype l_px_t is unsigned(l_depth - 1 downto 0);
	type l_px_arr_t is array (integer range <>) of l_px_t;

	-- address types, can represent location of pixel
	subtype l_addr_t is integer range 0 to l_px_cnt - 1; -- a 1D address (row * width + col)
	type l_coord_t is array (0 to 1) of integer range 0 to l_height - 1; -- a 2D address (row, col)

	-- packed pixel type: an address concatenated with a pixel (39 downto 24 => addr, 23 downto 0 => data)
	subtype l_pack_t is unsigned(log(2, l_px_cnt) + l_depth - 1 downto 0);

	-- GPU program memory types
	subtype p_addr_t is u8_t; -- program address, up to 256 instructions
	subtype p_inst_t is unsigned(63 downto 0); -- program instruction

	--------------------------------------------------------------------------------
	-- color constants
	--------------------------------------------------------------------------------

	constant black   : l_px_t := x"000000";
	constant blue    : l_px_t := x"0000ff";
	constant red     : l_px_t := x"ff0000";
	constant magenta : l_px_t := x"ff00ff";
	constant green   : l_px_t := x"00ff00";
	constant cyan    : l_px_t := x"00ffff";
	constant yellow  : l_px_t := x"ffff00";
	constant white   : l_px_t := x"ffffff";

	--------------------------------------------------------------------------------
	-- functions
	--------------------------------------------------------------------------------

	-- to_coord, to_addr: returns coordinate/address of address/coordinate
	-- addr/coord: address/coordinate of the pixel
	-- p_width: width of the picture. If not given, l_width is used
	function to_coord(addr, p_width : integer) return l_coord_t;
	function to_coord(addr : integer) return l_coord_t;
	function to_addr(coord: l_coord_t; p_width : integer) return integer;
	function to_addr(coord: l_coord_t) return integer;

	-- to_addr, to_data: returns unpacked address/data
	-- pack: packed value to unpack
	function to_addr(pack : l_pack_t) return integer;
	function to_data(pack: l_pack_t) return l_px_t;

	-- l_paste: paste a picture on top of the frame
	-- l_addr: background address
	-- l_data: background data
	-- p_data: picture data
	-- p_coord: where the top-left corner of the picture is
	-- p_width, p_height: size of picture
	-- returns: packed picture address and framebuffer data
	-- example, pasting a 16x32 icon at the middle of screen: 
	--     PACK <= l_paste((56, 64), 16, 32, <lcd_addr|bg_addr>, bg_data, icon_data);
	--     lcd_data <= to_data(PACK);
	--     icon_addr <= to_addr(PACK);
	-- the function can be nested to paste multiple pictures
	function l_paste(l_addr : integer;
	                 l_data, p_data : l_px_t;
	                 p_coord : l_coord_t;
	                 p_width, p_height : integer) return l_pack_t;

	function l_paste_txt(l_addr : integer; 
                       l_data : l_px_t; txt : string;
                       txt_coord : l_coord_t; color : l_px_t) return l_px_t;

	-- l_rotate: returns the rotated address of a picture
	-- addr: the original address
	-- angle: 90 degrees clockwise to rotate. can be 0, 1, 2, 3
	-- p_width, p_height: the original width and height of picture
	function l_rotate(addr, angle, p_width, p_height : integer) return integer;

	-- l_mirror: returns mirrored address of a picture
	-- addr: the original address
	-- mode: 0: original, 1: Y-mirror, 2: X-mirror, 3: XY-mirror
	-- p_width, p_height: the original width and height of picture
	function l_mirror(addr, mode, p_width, p_height : integer) return integer;

	function l_scale(addr, p_width, scale : integer) return integer;

	-- l_map: change one color to another
	-- data: current picture data
	-- o_color: color that will be changed
	-- n_color: color that old_color will be changed into
	-- returns: mapped data
	function l_map(data, o_color, n_color: l_px_t) return l_px_t;

	--------------------------------------------------------------------------------
	-- command constants
	-- only the used commands are listed here
	--------------------------------------------------------------------------------

	constant l_slpout  : u8_t := x"11";
	constant l_frmctr1 : u8_t := x"b1";
	constant l_frmctr2 : u8_t := x"b2";
	constant l_frmctr3 : u8_t := x"b3";
	constant l_pwctr1  : u8_t := x"c0";
	constant l_pwctr2  : u8_t := x"c1";
	constant l_pwctr3  : u8_t := x"c2";
	constant l_pwctr4  : u8_t := x"c3";
	constant l_pwctr5  : u8_t := x"c4";
	constant l_vmctr1  : u8_t := x"c5";
	constant l_gmctrp1 : u8_t := x"e0"; -- aka gamctrp1
	constant l_gmctrn1 : u8_t := x"e1"; -- aka gamctrn1
	constant l_madctl  : u8_t := x"36";
	constant l_caset   : u8_t := x"2a";
	constant l_raset   : u8_t := x"2b";
	constant l_dispon  : u8_t := x"29";
	constant l_ramwr   : u8_t := x"2c";

	--------------------------------------------------------------------------------
	-- initialization commands and arguments
	--------------------------------------------------------------------------------

	constant l_init : u8_arr_t(0 to 79) := (
		l_frmctr1, x"05", x"3c", x"3c",
		l_frmctr2, x"05", x"3c", x"3c",
		l_frmctr3, x"05", x"3c", x"3c", x"05", x"3c", x"3c",
		l_pwctr1, x"28", x"08", x"04",
		l_pwctr2, x"c0",
		l_pwctr3, x"0d", x"00",
		l_pwctr4, x"8d", x"2a",
		l_pwctr5, x"8d", x"ee",
		l_vmctr1, x"1a",
		l_gmctrp1, x"04", x"22", x"07", x"0a", x"2e", x"30", x"25", x"2a", x"28", x"26", x"2e", x"3a", x"00", x"01", x"03", x"13",
		l_gmctrn1, x"04", x"16", x"06", x"0d", x"2d", x"26", x"23", x"27", x"27", x"25", x"2d", x"3b", x"00", x"01", x"04", x"13",
		l_madctl, x"c0",
		l_caset, x"00", x"02", x"00", x"81",
		l_raset, x"00", x"01", x"00", x"a0",
		l_dispon,
		l_ramwr
	);
	constant l_init_dc : std_logic_vector(0 to 79) := "01110111011111101110101101101101011111111111111110111111111111111101011110111100";

	--------------------------------------------------------------------------------
	-- font
	-- HD44780 5x7 pixel font data, http://eleif.net/HD44780.html 
	-- Array index is the relative ASCII code
	--------------------------------------------------------------------------------

	type glyph_t is array (0 to 6) of unsigned(0 to 4);
	type font_t is array (32 to 127) of glyph_t;

	constant l_font : font_t := (-- this comment is for the formatter
	("00000", "00000", "00000", "00000", "00000", "00000", "00000"), -- [ 32] ' '
	("00100", "00100", "00100", "00100", "00000", "00000", "00100"), -- [ 33] '!'
	("01010", "01010", "01010", "00000", "00000", "00000", "00000"), -- [ 34] '"'
	("01010", "01010", "11111", "01010", "11111", "01010", "01010"), -- [ 35] '#'
	("00100", "01111", "10100", "01110", "00101", "11110", "00100"), -- [ 36] '$'
	("11000", "11001", "00010", "00100", "01000", "10011", "00011"), -- [ 37] '%'
	("01100", "10010", "10100", "01000", "10101", "10010", "01101"), -- [ 38] '&'
	("01100", "00100", "01000", "00000", "00000", "00000", "00000"), -- [ 39] '''
	("00010", "00100", "01000", "01000", "01000", "00100", "00010"), -- [ 40] '('
	("01000", "00100", "00010", "00010", "00010", "00100", "01000"), -- [ 41] ')'
	("00000", "00100", "10101", "01110", "10101", "00100", "00000"), -- [ 42] '*'
	("00000", "00100", "00100", "11111", "00100", "00100", "00000"), -- [ 43] '+'
	("00000", "00000", "00000", "00000", "01100", "00100", "01000"), -- [ 44] ','
	("00000", "00000", "00000", "11111", "00000", "00000", "00000"), -- [ 45] '-'
	("00000", "00000", "00000", "00000", "00000", "01100", "01100"), -- [ 46] '.'
	("00000", "00001", "00010", "00100", "01000", "10000", "00000"), -- [ 47] '/'
	("01110", "10001", "10011", "10101", "11001", "10001", "01110"), -- [ 48] '0'
	("00100", "01100", "00100", "00100", "00100", "00100", "01110"), -- [ 49] '1'
	("01110", "10001", "00001", "00010", "00100", "01000", "11111"), -- [ 50] '2'
	("11111", "00010", "00100", "00010", "00001", "10001", "01110"), -- [ 51] '3'
	("00010", "00110", "01010", "10010", "11111", "00010", "00010"), -- [ 52] '4'
	("11111", "10000", "11110", "00001", "00001", "10001", "01110"), -- [ 53] '5'
	("00110", "01000", "10000", "11110", "10001", "10001", "01110"), -- [ 54] '6'
	("11111", "10001", "00001", "00010", "00100", "00100", "00100"), -- [ 55] '7'
	("01110", "10001", "10001", "01110", "10001", "10001", "01110"), -- [ 56] '8'
	("01110", "10001", "10001", "01111", "00001", "00010", "01100"), -- [ 57] '9'
	("00000", "01100", "01100", "00000", "01100", "01100", "00000"), -- [ 58] ':'
	("00000", "01100", "01100", "00000", "01100", "00100", "01000"), -- [ 59] ';'
	("00010", "00100", "01000", "10000", "01000", "00100", "00010"), -- [ 60] '<'
	("00000", "00000", "11111", "00000", "11111", "00000", "00000"), -- [ 61] '='
	("01000", "00100", "00010", "00001", "00010", "00100", "01000"), -- [ 62] '>'
	("01110", "10001", "00001", "00010", "00100", "00000", "00100"), -- [ 63] '?'
	("01110", "10001", "00001", "01101", "10101", "10101", "01110"), -- [ 64] '@'
	("01110", "10001", "10001", "10001", "11111", "10001", "10001"), -- [ 65] 'A'
	("11110", "10001", "10001", "11110", "10001", "10001", "11110"), -- [ 66] 'B'
	("01110", "10001", "10000", "10000", "10000", "10001", "01110"), -- [ 67] 'C'
	("11100", "10010", "10001", "10001", "10001", "10010", "11100"), -- [ 68] 'D'
	("11111", "10000", "10000", "11110", "10000", "10000", "11111"), -- [ 69] 'E'
	("11111", "10000", "10000", "11110", "10000", "10000", "10000"), -- [ 70] 'F'
	("01110", "10001", "10000", "10111", "10001", "10001", "01111"), -- [ 71] 'G'
	("10001", "10001", "10001", "11111", "10001", "10001", "10001"), -- [ 72] 'H'
	("01110", "00100", "00100", "00100", "00100", "00100", "01110"), -- [ 73] 'I'
	("00111", "00010", "00010", "00010", "00010", "10010", "01100"), -- [ 74] 'J'
	("10001", "10010", "10100", "11000", "10100", "10010", "10001"), -- [ 75] 'K'
	("10000", "10000", "10000", "10000", "10000", "10000", "11111"), -- [ 76] 'L'
	("10001", "11011", "10101", "10101", "10001", "10001", "10001"), -- [ 77] 'M'
	("10001", "10001", "11001", "10101", "10011", "10001", "10001"), -- [ 78] 'N'
	("01110", "10001", "10001", "10001", "10001", "10001", "01110"), -- [ 79] 'O'
	("11110", "10001", "10001", "11110", "10000", "10000", "10000"), -- [ 80] 'P'
	("01110", "10001", "10001", "10001", "10101", "10010", "01101"), -- [ 81] 'Q'
	("11110", "10001", "10001", "11110", "10100", "10010", "10001"), -- [ 82] 'R'
	("01111", "10000", "10000", "01110", "00001", "00001", "11110"), -- [ 83] 'S'
	("11111", "00100", "00100", "00100", "00100", "00100", "00100"), -- [ 84] 'T'
	("10001", "10001", "10001", "10001", "10001", "10001", "01110"), -- [ 85] 'U'
	("10001", "10001", "10001", "10001", "10001", "01010", "00100"), -- [ 86] 'V'
	("10001", "10001", "10001", "10101", "10101", "10101", "01010"), -- [ 87] 'W'
	("10001", "10001", "01010", "00100", "01010", "10001", "10001"), -- [ 88] 'X'
	("10001", "10001", "10001", "01010", "00100", "00100", "00100"), -- [ 89] 'Y'
	("11111", "00001", "00010", "00100", "01000", "10000", "11111"), -- [ 90] 'Z'
	("11100", "10000", "10000", "10000", "10000", "10000", "11100"), -- [ 91] '['
	("10001", "01010", "11111", "00100", "11111", "00100", "00100"), -- [ 92] '\'
	("01110", "00010", "00010", "00010", "00010", "00010", "01110"), -- [ 93] ']'
	("00100", "01010", "10001", "00000", "00000", "00000", "00000"), -- [ 94] '^'
	("00000", "00000", "00000", "00000", "00000", "00000", "11111"), -- [ 95] '_'
	("01000", "00100", "00010", "00000", "00000", "00000", "00000"), -- [ 96] '`'
	("00000", "00000", "01110", "00001", "01111", "10001", "01111"), -- [ 97] 'a'
	("10000", "10000", "10110", "11001", "10001", "10001", "11110"), -- [ 98] 'b'
	("00000", "00000", "01110", "10000", "10000", "10001", "01110"), -- [ 99] 'c'
	("00001", "00001", "01101", "10011", "10001", "10001", "01111"), -- [100] 'd'
	("00000", "00000", "01110", "10001", "11111", "10000", "01110"), -- [101] 'e'
	("00110", "01001", "01000", "11100", "01000", "01000", "01000"), -- [102] 'f'
	("00000", "01111", "10001", "10001", "01111", "00001", "01110"), -- [103] 'g'
	("10000", "10000", "10110", "11001", "10001", "10001", "10001"), -- [104] 'h'
	("00100", "00000", "01100", "00100", "00100", "00100", "01110"), -- [105] 'i'
	("00010", "00000", "00110", "00010", "00010", "10010", "01100"), -- [106] 'j'
	("10000", "10000", "10010", "10100", "11000", "10100", "10010"), -- [107] 'k'
	("01100", "00100", "00100", "00100", "00100", "00100", "01110"), -- [108] 'l'
	("00000", "00000", "11010", "10101", "10101", "10001", "10001"), -- [109] 'm'
	("00000", "00000", "10110", "11001", "10001", "10001", "10001"), -- [110] 'n'
	("00000", "00000", "01110", "10001", "10001", "10001", "01110"), -- [111] 'o'
	("00000", "00000", "11110", "10001", "11110", "10000", "10000"), -- [112] 'p'
	("00000", "00000", "01101", "10011", "01111", "00001", "00001"), -- [113] 'q'
	("00000", "00000", "10110", "11001", "10000", "10000", "10000"), -- [114] 'r'
	("00000", "00000", "01110", "10000", "01110", "00001", "11110"), -- [115] 's'
	("01000", "01000", "11100", "01000", "01000", "01001", "00110"), -- [116] 't'
	("00000", "00000", "10001", "10001", "10001", "10011", "01101"), -- [117] 'u'
	("00000", "00000", "10001", "10001", "10001", "01010", "00100"), -- [118] 'v'
	("00000", "00000", "10001", "10101", "10101", "10101", "01010"), -- [119] 'w'
	("00000", "00000", "10001", "01010", "00100", "01010", "10001"), -- [120] 'x'
	("00000", "00000", "10001", "10001", "01111", "00001", "01110"), -- [121] 'y'
	("00000", "00000", "11111", "00010", "00100", "01000", "11111"), -- [122] 'z'
	("00010", "00100", "00100", "01000", "00100", "00100", "00010"), -- [123] '{'
	("00100", "00100", "00100", "00100", "00100", "00100", "00100"), -- [124] '|'
	("01000", "00100", "00100", "00010", "00100", "00100", "01000"), -- [125] '}'
	("00000", "00100", "00010", "11111", "00010", "00100", "00000"), -- [126] '~' -- right arrow
	("00000", "00100", "01000", "11111", "01000", "00100", "00000") --  [127] '' -- left arrow
	);
end package;

package body itc_lcd is
	function "+"(left, right : l_coord_t) return l_coord_t is begin
		return (left(0) + right(0), left(1) + right(1));
	end function;
	
	function "-"(left, right : l_coord_t) return l_coord_t is begin
		return (left(0) - right(0), left(1) - right(1));
	end function;

	function "*"(left : l_coord_t; right : integer) return l_coord_t is begin
		return (left(0) * right, left(1) * right);
	end function;

	function to_coord(addr, p_width : integer) return l_coord_t is begin
		return (addr / p_width, addr mod p_width);
	end function;

	function to_coord(addr : integer) return l_coord_t is begin
		return to_coord(addr, l_width);
	end function;

	function to_addr(coord: l_coord_t; p_width : integer) return integer is begin
		return coord(0) * p_width + coord(1);
	end function;

	function to_addr(coord: l_coord_t) return integer is begin
		return to_addr(coord, l_width);
	end function;

	function to_addr(pack : l_pack_t) return integer is begin
		return to_integer(pack srl l_px_t'length); -- right shift the data away
	end function;

	function to_data(pack: l_pack_t) return l_px_t is begin
		return pack(l_px_t'range);
	end function;

	function l_rotate(addr, angle, p_width, p_height : integer) return integer is
		constant row : integer := to_coord(addr, p_width)(0);
		constant col : integer := to_coord(addr, p_width)(1);
	begin
		case angle is
			when 0 =>
				return addr; -- or row * p_width + col
			when 1 =>
				return col * p_height + (p_height - row - 1);
			when 2 =>
				return p_width * p_height - addr - 1; -- reverse
			when 3 =>
				return (p_width - col - 1) * p_height + row;
			when others => 
				return addr;
		end case; 
	end function;

	function l_mirror(addr, mode, p_width, p_height : integer) return integer is
		constant row : integer := to_coord(addr, p_width)(0);
		constant col : integer := to_coord(addr, p_width)(1);
	begin
		case mode is
			when 0 =>
				return addr; -- or row * p_width + col
			when 1 =>
				return to_addr((row, p_width - col - 1), p_width);
			when 2 =>
				return to_addr((p_height - row - 1, col), p_width);
			when 3 =>
				return to_addr((p_height - row - 1, p_width - col - 1), p_width);
			when others => 
				return addr;
		end case; 
	end function;

	function l_map(data, o_color, n_color: l_px_t) return l_px_t is begin
		if data = o_color then
			return n_color;
		else
			return data;
		end if;
	end function;

	function l_paste(l_addr : integer;
					 l_data, p_data : l_px_t;
					 p_coord : l_coord_t;
					 p_width, p_height : integer) return l_pack_t is
		constant l_coord : l_coord_t := to_coord(l_addr);
		constant p_coord_end : l_coord_t := (p_coord(0) + p_height - 1, p_coord(1) + p_width - 1);
	begin
		if p_coord(0) <= l_coord(0) and l_coord(0) <= p_coord_end(0) and  -- check row
		   p_coord(1) <= l_coord(1) and l_coord(1) <= p_coord_end(1) then -- check column
			return to_unsigned(to_addr(l_coord - p_coord, p_width), l_addr_width) & p_data;
		else
			return to_unsigned(0, l_addr_width) & l_data;
		end if;
	end function;

	function l_paste_txt(l_addr : integer; 
						 l_data : l_px_t; txt : string;
						 txt_coord : l_coord_t;color : l_px_t) return l_px_t is
		constant txt_width : integer := txt'length * 5;
		constant txt_height : integer := 7;
		constant l_coord : l_coord_t := to_coord(l_addr);
		constant txt_coord_end : l_coord_t := (txt_coord(0) + txt_height - 1, txt_coord(1) + txt_width - 1);
		constant addr : integer := to_addr((l_coord - txt_coord), txt_width);
		constant char_cnt : integer := (addr / 5) mod txt'length + 1;
		constant char_row : integer := addr / 5 / txt'length;
		constant char_col : integer := addr mod 5;
	begin
		if txt_coord(0) <= l_coord(0) and l_coord(0) <= txt_coord_end(0) and  -- check row
		   txt_coord(1) <= l_coord(1) and l_coord(1) <= txt_coord_end(1) then -- check column
			if l_font(character'pos(txt(char_cnt)))(char_row)(char_col) = '1' then
				return color;
			else
				return white;
			end if;
		else
			return l_data;
		end if;
	end function;

	function l_scale(addr, p_width, scale : integer) return integer is
		constant coord : l_coord_t := to_coord(addr, p_width);
	begin
		return to_addr(coord * scale, p_width);
	end function;
end package body;
