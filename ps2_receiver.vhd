library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ps2_receiver is
  generic (
    clock_frequency_hz : natural := 50_000_000  -- board crystal (EE03 kit: 50 MHz)
  );
  port (
    system_clock        : in  std_logic;
    ps2_clock           : in  std_logic;         -- clock coming from the keyboard
    ps2_data            : in  std_logic;         -- data coming from the keyboard
    received_byte       : out std_logic_vector(7 downto 0);
    received_byte_valid : out std_logic          -- '1' for one clock cycle per byte
  );
end ps2_receiver;


architecture behavior of ps2_receiver is

  -- If no ps2_clock edge arrives for 2 ms in the middle of a frame, give up
  -- on that frame and wait for a new start bit.
  constant FRAME_TIMEOUT_CYCLES : natural := clock_frequency_hz / 500;

  -- Delay lines used to synchronize the inputs and detect the falling edge
  signal ps2_clock_delay_line : std_logic_vector(2 downto 0) := "111";
  signal ps2_data_delay_line  : std_logic_vector(1 downto 0) := "11";

  -- Which bit of the frame is expected next:
  --   0 = start bit, 1 to 8 = data bits, 9 = parity bit, 10 = stop bit
  signal expected_bit_number : natural range 0 to 10 := 0;

  -- Data bits collected so far
  signal collected_data_bits : std_logic_vector(7 downto 0) := (others => '0');

  -- Cycles elapsed since the last falling edge of ps2_clock
  signal cycles_without_clock_edge : natural range 0 to FRAME_TIMEOUT_CYCLES := 0;

begin

  process (system_clock)
  begin
    if rising_edge(system_clock) then

      -- The valid flag is a one-cycle pulse, so it is '0' unless set below
      received_byte_valid <= '0';

      -- Shift the new samples into the delay lines
      ps2_clock_delay_line <= ps2_clock_delay_line(1 downto 0) & ps2_clock;
      ps2_data_delay_line  <= ps2_data_delay_line(0) & ps2_data;

      -- Falling edge of ps2_clock: previous sample was '1', newer one is '0'.
      -- ps2_data_delay_line(1) is aligned in time with ps2_clock_delay_line(1).
      if ps2_clock_delay_line(2) = '1' and ps2_clock_delay_line(1) = '0' then

        cycles_without_clock_edge <= 0;

        case expected_bit_number is

          when 0 =>
            -- Start bit: must be '0', otherwise ignore it
            if ps2_data_delay_line(1) = '0' then
              expected_bit_number <= 1;
            end if;

          when 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 =>
            -- Data bits arrive LSB first, so each new bit enters from the left
            -- and the earlier bits move right.
            collected_data_bits <= ps2_data_delay_line(1) &
                                   collected_data_bits(7 downto 1);
            expected_bit_number <= expected_bit_number + 1;

          when 9 =>
            -- Parity bit: not checked (keep it simple)
            expected_bit_number <= 10;

          when others =>
            -- Stop bit: must be '1'. If so, the byte is complete.
            expected_bit_number <= 0;
            if ps2_data_delay_line(1) = '1' then
              received_byte       <= collected_data_bits;
              received_byte_valid <= '1';
            end if;

        end case;

      elsif expected_bit_number /= 0 then
        -- In the middle of a frame with no clock edge: count towards timeout
        if cycles_without_clock_edge = FRAME_TIMEOUT_CYCLES then
          expected_bit_number       <= 0;
          cycles_without_clock_edge <= 0;
        else
          cycles_without_clock_edge <= cycles_without_clock_edge + 1;
        end if;
      end if;

    end if;
  end process;

end behavior;
