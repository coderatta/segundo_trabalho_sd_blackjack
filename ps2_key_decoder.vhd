library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ps2_key_decoder is
  port (
    system_clock        : in  std_logic;
    received_byte       : in  std_logic_vector(7 downto 0);
    received_byte_valid : in  std_logic;

    pressed_digit_value : out std_logic_vector(3 downto 0); -- 1 to 9
    digit_key_pressed   : out std_logic;                    -- one-cycle pulse
    enter_key_pressed   : out std_logic                     -- one-cycle pulse
  );
end ps2_key_decoder;


architecture behavior of ps2_key_decoder is

  -- '1' if the previous byte was F0 (the next byte is a key RELEASE code)
  signal release_code_just_received : std_logic := '0';

  -- '1' while a key is physically held down (used to ignore auto-repeat)
  signal a_key_is_held_down : std_logic := '0';

  -- Make code of the key that is currently held down
  signal held_key_make_code : std_logic_vector(7 downto 0) := (others => '0');

begin

  process (system_clock)
  begin
    if rising_edge(system_clock) then

      -- Events are one-cycle pulses
      digit_key_pressed <= '0';
      enter_key_pressed <= '0';

      if received_byte_valid = '1' then

        case received_byte is

          when X"F0" =>
            -- Next byte will be a key release
            release_code_just_received <= '1';

          when X"E0" | X"E1" =>
            -- Prefix of extended keys: nothing to do, the next byte is handled normally
            null;

          when others =>

            if release_code_just_received = '1' then
              -- This byte is a key being released: just clear the flags
              release_code_just_received <= '0';
              a_key_is_held_down         <= '0';

            elsif a_key_is_held_down = '1' and received_byte = held_key_make_code then
              -- Same key repeating because it is held down: ignore
              null;

            else
              -- A new key press: remember it and look up what it is
              held_key_make_code <= received_byte;
              a_key_is_held_down <= '1';

              case received_byte is
                --        top row        keypad
                when X"16" | X"69" => pressed_digit_value <= "0001"; digit_key_pressed <= '1'; -- 1
                when X"1E" | X"72" => pressed_digit_value <= "0010"; digit_key_pressed <= '1'; -- 2
                when X"26" | X"7A" => pressed_digit_value <= "0011"; digit_key_pressed <= '1'; -- 3
                when X"25" | X"6B" => pressed_digit_value <= "0100"; digit_key_pressed <= '1'; -- 4
                when X"2E" | X"73" => pressed_digit_value <= "0101"; digit_key_pressed <= '1'; -- 5
                when X"36" | X"74" => pressed_digit_value <= "0110"; digit_key_pressed <= '1'; -- 6
                when X"3D" | X"6C" => pressed_digit_value <= "0111"; digit_key_pressed <= '1'; -- 7
                when X"3E" | X"75" => pressed_digit_value <= "1000"; digit_key_pressed <= '1'; -- 8
                when X"46" | X"7D" => pressed_digit_value <= "1001"; digit_key_pressed <= '1'; -- 9
                when X"5A"         => enter_key_pressed <= '1';                                -- Enter
                when others        => null;                                                    -- any other key
              end case;
            end if;

        end case;
      end if;

    end if;
  end process;

end behavior;
