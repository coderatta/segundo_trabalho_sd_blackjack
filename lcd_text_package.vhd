library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package lcd_text_package is

  -- One LCD line: 16 columns (0 to 15), each one an 8-bit ASCII code
  type lcd_line_type is array (0 to 15) of std_logic_vector(7 downto 0);

  -- ASCII code of the blank character
  constant ASCII_SPACE : std_logic_vector(7 downto 0) := X"20";

  -- Returns value / 10 (works for 0 to 39). Written with comparisons because
  -- the Xilinx synthesizer only divides by powers of two.
  function tens_digit_of (value : natural) return natural;

  -- Returns the ASCII code of a single digit (0 to 9)
  function digit_to_ascii (digit_value : natural) return std_logic_vector;

  -- Writes a constant text into the line, starting at start_column
  procedure write_text (variable line         : inout lcd_line_type;
                        constant start_column : in    natural;
                        constant text         : in    string);

  -- Writes a number (0 to 39) into the line, starting at start_column.
  -- One digit  -> uses 1 column  (example: "7")
  -- Two digits -> uses 2 columns (example: "17")
  procedure write_number (variable line         : inout lcd_line_type;
                          constant start_column : in    natural;
                          constant value        : in    natural);

end package lcd_text_package;


package body lcd_text_package is

  function tens_digit_of (value : natural) return natural is
  begin
    if    value >= 30 then return 3;
    elsif value >= 20 then return 2;
    elsif value >= 10 then return 1;
    else                   return 0;
    end if;
  end function;

  function digit_to_ascii (digit_value : natural) return std_logic_vector is
  begin
    -- ASCII '0' is 48, '1' is 49, ... '9' is 57
    return std_logic_vector(to_unsigned(48 + digit_value, 8));
  end function;

  procedure write_text (variable line         : inout lcd_line_type;
                        constant start_column : in    natural;
                        constant text         : in    string) is
  begin
    for character_index in text'range loop
      line(start_column + character_index - text'low) :=
        std_logic_vector(to_unsigned(character'pos(text(character_index)), 8));
    end loop;
  end procedure;

  procedure write_number (variable line         : inout lcd_line_type;
                          constant start_column : in    natural;
                          constant value        : in    natural) is
    variable tens_digit  : natural range 0 to 3;
    variable units_digit : natural range 0 to 9;
  begin
    tens_digit  := tens_digit_of(value);
    units_digit := value - (10 * tens_digit);

    if value < 10 then
      -- Single digit: written right at start_column (no gap after the word)
      line(start_column) := digit_to_ascii(units_digit);
    else
      line(start_column)     := digit_to_ascii(tens_digit);
      line(start_column + 1) := digit_to_ascii(units_digit);
    end if;
  end procedure;

end package body lcd_text_package;
