library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.lcd_text_package.all;

entity game_21_top is
  generic (
    clock_frequency_hz : natural := 50_000_000
  );
  port (
    system_clock        : in  std_logic;        -- 50 MHz board clock

    -- PS/2 keyboard connector
    ps2_clock           : in  std_logic;
    ps2_data            : in  std_logic;

    -- 16x2 LCD
    lcd_register_select : out std_logic;        -- RS
    lcd_read_write      : out std_logic;        -- RW
    lcd_enable          : out std_logic;        -- E
    lcd_data_bus        : out std_logic_vector(7 downto 0)  -- DB7..DB0
  );
end game_21_top;


architecture structural of game_21_top is

  -- Byte received from the keyboard
  signal received_byte        : std_logic_vector(7 downto 0);
  signal received_byte_valid  : std_logic;

  -- Events decoded from the keyboard
  signal pressed_digit_value  : std_logic_vector(3 downto 0);
  signal digit_key_pressed    : std_logic;
  signal enter_key_pressed    : std_logic;

  -- Text lines produced by the game and shown by the LCD
  signal lcd_top_line         : lcd_line_type;
  signal lcd_bottom_line      : lcd_line_type;

begin

  keyboard_receiver : entity work.ps2_receiver
    generic map (clock_frequency_hz => clock_frequency_hz)
    port map (
      system_clock        => system_clock,
      ps2_clock           => ps2_clock,
      ps2_data            => ps2_data,
      received_byte       => received_byte,
      received_byte_valid => received_byte_valid
    );

  keyboard_decoder : entity work.ps2_key_decoder
    port map (
      system_clock        => system_clock,
      received_byte       => received_byte,
      received_byte_valid => received_byte_valid,
      pressed_digit_value => pressed_digit_value,
      digit_key_pressed   => digit_key_pressed,
      enter_key_pressed   => enter_key_pressed
    );

  game_logic : entity work.game_21
    generic map (clock_frequency_hz => clock_frequency_hz)
    port map (
      system_clock        => system_clock,
      pressed_digit_value => pressed_digit_value,
      digit_key_pressed   => digit_key_pressed,
      enter_key_pressed   => enter_key_pressed,
      lcd_top_line        => lcd_top_line,
      lcd_bottom_line     => lcd_bottom_line
    );

  lcd_display : entity work.lcd_driver
    generic map (clock_frequency_hz => clock_frequency_hz)
    port map (
      system_clock        => system_clock,
      lcd_top_line        => lcd_top_line,
      lcd_bottom_line     => lcd_bottom_line,
      lcd_register_select => lcd_register_select,
      lcd_read_write      => lcd_read_write,
      lcd_enable          => lcd_enable,
      lcd_data_bus        => lcd_data_bus
    );

end structural;
