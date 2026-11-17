library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.lcd_text_package.all;

entity game_21 is
  generic (
    clock_frequency_hz : natural := 50_000_000
  );
  port (
    system_clock        : in  std_logic;

    -- Events coming from the keyboard decoder
    pressed_digit_value : in  std_logic_vector(3 downto 0);  -- 1 to 9
    digit_key_pressed   : in  std_logic;                     -- one-cycle pulse
    enter_key_pressed   : in  std_logic;                     -- one-cycle pulse

    -- Text to be shown on the LCD
    lcd_top_line        : out lcd_line_type;
    lcd_bottom_line     : out lcd_line_type
  );
end game_21;


architecture behavior of game_21 is
  -- Game rules
  constant MAXIMUM_ALLOWED_SUM       : natural := 21;  -- going beyond this loses
  constant BOARD_STOPS_AT_SUM        : natural := 17;  -- board stops at 17 or more
  -- Where the text appears on the top row of the LCD (columns 0 to 15)
  constant PLAYER_WORD_COLUMN        : natural := 4;   -- "PLAYER" uses columns 4 to 9
  constant PLAYER_SUM_COLUMN         : natural := 11;  -- column 10 is the space
  constant BOARD_WORD_COLUMN         : natural := 4;   -- "BOARD" uses columns 4 to 8
  constant BOARD_SUM_COLUMN          : natural := 10;  -- column 9 is the space
  constant RESULT_WORD_COLUMN        : natural := 5;   -- 6-letter words use columns 5 to 10
  -- Game states (one for each thing that can be happening)
  type game_state_type is (
    STATE_PLAYER_PLAYING,        -- screen 1: player adds numbers
    STATE_PLAYER_WENT_OVER_21,   -- screen 2 (bust): shows "PERDEU", waits Enter
    STATE_BOARD_PLAYING,         -- screen 2: board adds a number every second
    STATE_BOARD_STOPPED,         -- screen 2: board finished, waits Enter
    STATE_SHOWING_RESULT         -- screen 3: "GANHOU" / "PERDEU" / "EMPATE"
  );

  type game_result_type is (
    RESULT_PLAYER_WON,
    RESULT_PLAYER_LOST,
    RESULT_TIE
  );

  signal current_game_state : game_state_type  := STATE_PLAYER_PLAYING;
  signal final_game_result  : game_result_type := RESULT_TIE;

  signal player_sum : natural range 0 to 63 := 0;
  signal board_sum  : natural range 0 to 63 := 0;

  -- Counts board-clock cycles until one second has passed
  signal clock_cycles_since_last_board_draw : natural range 0 to clock_frequency_hz - 1 := 0;

  ---------------------------------------------------------------------------
  -- Random number generator.
  -- A 16-bit shift register (LFSR) changes at every clock cycle, and the
  -- latest value that falls between 1 and 9 is kept in random_number_1_to_9.
  -- The board draws the number once per second.
  ---------------------------------------------------------------------------
  signal random_shift_register : std_logic_vector(15 downto 0) := X"ACE1";
  signal random_number_1_to_9  : natural range 1 to 9 := 1;

begin
  -- Process 1: the game
  game_state_machine : process (system_clock)
    variable new_sum_value        : natural range 0 to 63;
    variable candidate_random_nibble : natural range 0 to 15;
  begin
    if rising_edge(system_clock) then

      -- Random number generator: shift left and feed back an XOR of some bits
      random_shift_register <= random_shift_register(14 downto 0) &
                               (random_shift_register(15) xor random_shift_register(13) xor
                                random_shift_register(12) xor random_shift_register(10));

      -- Take 4 bits; only accept them if they are a valid number from 1 to 9
      candidate_random_nibble := to_integer(unsigned(random_shift_register(3 downto 0)));
      if candidate_random_nibble >= 1 and candidate_random_nibble <= 9 then
        random_number_1_to_9 <= candidate_random_nibble;
      end if;

      case current_game_state is

        -- Player turn
        when STATE_PLAYER_PLAYING =>
          if digit_key_pressed = '1' then
            new_sum_value := player_sum + to_integer(unsigned(pressed_digit_value));
            player_sum    <= new_sum_value;

            if new_sum_value > MAXIMUM_ALLOWED_SUM then
              current_game_state <= STATE_PLAYER_WENT_OVER_21;
            end if;

          elsif enter_key_pressed = '1' then
            board_sum                          <= 0;
            clock_cycles_since_last_board_draw <= 0;
            current_game_state                 <= STATE_BOARD_PLAYING;
          end if;

        -- Player going over 21. Enter restarts the game.
        when STATE_PLAYER_WENT_OVER_21 =>
          if enter_key_pressed = '1' then
            player_sum         <= 0;
            board_sum          <= 0;
            current_game_state <= STATE_PLAYER_PLAYING;
          end if;

        -- Board adds one random number per second until it has 17 or more.
        when STATE_BOARD_PLAYING =>
          if clock_cycles_since_last_board_draw = clock_frequency_hz - 1 then
            -- One second has passed: the board chooses a number
            clock_cycles_since_last_board_draw <= 0;
            new_sum_value := board_sum + random_number_1_to_9;
            board_sum     <= new_sum_value;

            if new_sum_value >= BOARD_STOPS_AT_SUM then
              current_game_state <= STATE_BOARD_STOPPED;
            end if;
          else
            clock_cycles_since_last_board_draw <= clock_cycles_since_last_board_draw + 1;
          end if;

        -- Board has stopped. Enter goes to the result screen.
        when STATE_BOARD_STOPPED =>
          if enter_key_pressed = '1' then

            if board_sum > MAXIMUM_ALLOWED_SUM then
              final_game_result <= RESULT_PLAYER_WON;    -- board went over 21
            elsif player_sum > board_sum then
              final_game_result <= RESULT_PLAYER_WON;    -- player is closer to 21
            elsif board_sum > player_sum then
              final_game_result <= RESULT_PLAYER_LOST;   -- board is closer to 21
            else
              final_game_result <= RESULT_TIE;           -- same sum
            end if;

            current_game_state <= STATE_SHOWING_RESULT;
          end if;

        -- Result is on screen. Enter restarts the game.
        when STATE_SHOWING_RESULT =>
          if enter_key_pressed = '1' then
            player_sum         <= 0;
            board_sum          <= 0;
            current_game_state <= STATE_PLAYER_PLAYING;
          end if;

      end case;
    end if;
  end process game_state_machine;


  -- Process 2: builds the text shown on the LCD from the current state.
  -- (Combinational: it re-runs whenever one of the signals changes.)
  build_lcd_text : process (current_game_state, final_game_result, player_sum, board_sum)
    variable top_line_text    : lcd_line_type;
    variable bottom_line_text : lcd_line_type;
  begin
    -- Start with two empty lines
    top_line_text    := (others => ASCII_SPACE);
    bottom_line_text := (others => ASCII_SPACE);

    case current_game_state is

      when STATE_PLAYER_PLAYING =>
        -- "PLAYER 0" (centered; the sum starts one space after the word)
        write_text  (top_line_text, PLAYER_WORD_COLUMN, "PLAYER");
        write_number(top_line_text, PLAYER_SUM_COLUMN,  player_sum);

      when STATE_PLAYER_WENT_OVER_21 =>
        write_text(top_line_text, RESULT_WORD_COLUMN, "PERDEU");

      when STATE_BOARD_PLAYING | STATE_BOARD_STOPPED =>
        -- "BOARD 0" (centered; the sum starts one space after the word)
        write_text  (top_line_text, BOARD_WORD_COLUMN, "BOARD");
        write_number(top_line_text, BOARD_SUM_COLUMN,  board_sum);

      when STATE_SHOWING_RESULT =>
        case final_game_result is
          when RESULT_PLAYER_WON  => write_text(top_line_text, RESULT_WORD_COLUMN, "GANHOU");
          when RESULT_PLAYER_LOST => write_text(top_line_text, RESULT_WORD_COLUMN, "PERDEU");
          when RESULT_TIE         => write_text(top_line_text, RESULT_WORD_COLUMN, "EMPATE");
        end case;

    end case;

    lcd_top_line    <= top_line_text;
    lcd_bottom_line <= bottom_line_text;
  end process build_lcd_text;

end behavior;
