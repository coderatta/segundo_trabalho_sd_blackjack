library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.lcd_text_package.all;

entity lcd_driver is
  generic (
    clock_frequency_hz : natural := 50_000_000
  );
  port (
    system_clock        : in  std_logic;
    lcd_top_line        : in  lcd_line_type;     -- text for the first row
    lcd_bottom_line     : in  lcd_line_type;     -- text for the second row

    lcd_register_select : out std_logic;         -- RS: '0' = command, '1' = character
    lcd_read_write      : out std_logic;         -- RW: always '0' (we only write)
    lcd_enable          : out std_logic;         -- E : 500 Hz enable clock
    lcd_data_bus        : out std_logic_vector(7 downto 0)  -- DB7..DB0
  );
end lcd_driver;


architecture behavior of lcd_driver is

  -- E changes level every 1 ms -> 1 kHz toggling -> 500 Hz square wave
  constant CLOCK_CYCLES_PER_ENABLE_HALF_PERIOD : natural := clock_frequency_hz / 1000;

  ---------------------------------------------------------------------------
  -- The sequence of bytes sent to the LCD, numbered as "steps":
  --   steps  0 to 15 : "Function Set" command, repeated 16 times. The repeats
  --                    also serve as the power-up wait (16 x 2 ms = 32 ms)
  --   step   16      : Clear Display
  --   step   17      : Display ON (cursor hidden)
  --   step   18      : Entry Mode (cursor moves right after each character)
  --   step   19      : move cursor to the start of the top row
  --   steps 20 to 35 : the 16 characters of the top row
  --   step   36      : move cursor to the start of the bottom row
  --   steps 37 to 52 : the 16 characters of the bottom row
  --   then it goes back to step 19 and repeats forever
  ---------------------------------------------------------------------------
  constant LAST_FUNCTION_SET_STEP        : natural := 15;
  constant CLEAR_DISPLAY_STEP            : natural := 16;
  constant DISPLAY_ON_STEP               : natural := 17;
  constant ENTRY_MODE_STEP               : natural := 18;
  constant GO_TO_TOP_ROW_STEP            : natural := 19;
  constant FIRST_TOP_CHARACTER_STEP      : natural := 20;
  constant LAST_TOP_CHARACTER_STEP       : natural := 35;
  constant GO_TO_BOTTOM_ROW_STEP         : natural := 36;
  constant FIRST_BOTTOM_CHARACTER_STEP   : natural := 37;
  constant LAST_BOTTOM_CHARACTER_STEP    : natural := 52;

  signal enable_level_internal : std_logic := '0';  -- copy of E that we can read back
  signal clock_cycles_counter  : natural range 0 to CLOCK_CYCLES_PER_ENABLE_HALF_PERIOD := 0;
  signal current_step          : natural range 0 to LAST_BOTTOM_CHARACTER_STEP := 0;

begin

  lcd_enable     <= enable_level_internal;
  lcd_read_write <= '0; -- never read from the LCD

  process (system_clock)
  begin
    if rising_edge(system_clock) then

      if clock_cycles_counter = CLOCK_CYCLES_PER_ENABLE_HALF_PERIOD - 1 then

        -- 1 ms has passed: toggle E
        clock_cycles_counter  <= 0;
        enable_level_internal <= not enable_level_internal;

        -- E is currently '0' and is about to RISE: present the next byte now
        if enable_level_internal = '0' then

          if current_step <= LAST_FUNCTION_SET_STEP then
            lcd_register_select <= '0';
            lcd_data_bus        <= "00111000";      -- 8-bit bus, 2 rows, 5x8 font

          elsif current_step = CLEAR_DISPLAY_STEP then
            lcd_register_select <= '0';
            lcd_data_bus        <= "00000001";      -- clear display

          elsif current_step = DISPLAY_ON_STEP then
            lcd_register_select <= '0';
            lcd_data_bus        <= "00001100";      -- display on, cursor off

          elsif current_step = ENTRY_MODE_STEP then
            lcd_register_select <= '0';
            lcd_data_bus        <= "00000110";      -- cursor moves right

          elsif current_step = GO_TO_TOP_ROW_STEP then
            lcd_register_select <= '0';
            lcd_data_bus        <= "10000000";      -- set address 0x00 (top row, column 0)

          elsif current_step <= LAST_TOP_CHARACTER_STEP then
            lcd_register_select <= '1';             -- sending a character
            lcd_data_bus        <= lcd_top_line(current_step - FIRST_TOP_CHARACTER_STEP);

          elsif current_step = GO_TO_BOTTOM_ROW_STEP then
            lcd_register_select <= '0';
            lcd_data_bus        <= "11000000";      -- set address 0x40 (bottom row, column 0)

          else
            lcd_register_select <= '1';             -- sending a character
            lcd_data_bus        <= lcd_bottom_line(current_step - FIRST_BOTTOM_CHARACTER_STEP);
          end if;

          -- Prepare the next step (after the last one, loop back to the top row)
          if current_step = LAST_BOTTOM_CHARACTER_STEP then
            current_step <= GO_TO_TOP_ROW_STEP;
          else
            current_step <= current_step + 1;
          end if;

        end if;

      else
        clock_cycles_counter <= clock_cycles_counter + 1;
      end if;

    end if;
  end process;

end behavior;
