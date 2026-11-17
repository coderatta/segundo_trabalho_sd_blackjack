# Jogo de 21 em VHDL (Spartan-3A/3AN)

Versão simplificada do jogo de 21 (estilo blackjack) para a placa **Xilinx Spartan-3A/3AN Starter Kit**.
O jogador joga contra a "mesa" (o próprio FPGA), usando um **teclado PS/2** como entrada e o **display LCD 16x2** da placa como saída.

## Como jogar

O objetivo é chegar o mais perto possível de 21 sem passar. Quem passa de 21 perde a rodada.

| Tela | O que aparece | O que fazer |
|------|---------------|-------------|
| 1. Vez do jogador | `PLAYER 0` (a soma começa em 0) | Teclas **1 a 9** somam ao total. **Enter** passa a vez para a mesa. |
| 1b. Jogador estourou | `PERDEU` | Se a soma passar de 21, o jogo mostra `PERDEU`. **Enter** reinicia. |
| 2. Vez da mesa | `BOARD 0` | A mesa soma um número aleatório de 1 a 9 **a cada segundo** e para ao chegar a **17 ou mais**. Quando parar, **Enter** mostra o resultado. |
| 3. Resultado | `GANHOU`, `PERDEU` ou `EMPATE` | **Enter** inicia uma nova rodada. |

Regras do resultado:

- `GANHOU`: a mesa passou de 21, ou a soma do jogador é maior que a da mesa.
- `PERDEU`: o jogador passou de 21, ou a soma da mesa é maior.
- `EMPATE`: as somas são iguais.

## Estrutura do projeto

```
game_21_top.vhd        Topo: só liga os blocos e define as portas externas
game_21.vhd            Regras e estados do jogo (monta o texto das telas)
ps2_receiver.vhd       Recebe os bits do teclado e monta o byte (scan code)
ps2_key_decoder.vhd    Converte o scan code em "dígito 1-9" ou "Enter"
lcd_driver.vhd         Inicializa o LCD e reenvia as duas linhas continuamente
lcd_text_package.vhd   Tipos e funções de apoio para escrever texto no LCD
game_21.ucf            Associação das portas aos pinos físicos da placa
```

### Fluxo do sinal

```
Teclado PS/2 -> ps2_receiver -> ps2_key_decoder -> game_21 -> lcd_driver -> LCD 16x2
                          (system_clock de 50 MHz em todos os blocos)
```

### Resumo dos blocos

| Bloco | Entradas | Saídas |
|-------|----------|--------|
| `ps2_receiver` | `system_clock`, `ps2_clock`, `ps2_data` | `received_byte`, `received_byte_valid` |
| `ps2_key_decoder` | `system_clock`, `received_byte`, `received_byte_valid` | `pressed_digit_value`, `digit_key_pressed`, `enter_key_pressed` |
| `game_21` | `system_clock`, `pressed_digit_value`, `digit_key_pressed`, `enter_key_pressed` | `lcd_top_line`, `lcd_bottom_line` |
| `lcd_driver` | `system_clock`, `lcd_top_line`, `lcd_bottom_line` | `lcd_register_select`, `lcd_read_write`, `lcd_enable`, `lcd_data_bus` |

## Como funciona (resumo)

- **Teclado:** o teclado envia quadros de 11 bits (início, 8 dados, paridade, parada), um bit por borda de descida de `ps2_clock`. O `ps2_receiver` sincroniza os sinais com o clock da placa e entrega o byte. O `ps2_key_decoder` ignora a liberação das teclas (código `F0`) e a repetição automática, gerando um único pulso por aperto.
- **Jogo:** uma máquina de estados (`STATE_PLAYER_PLAYING`, `STATE_PLAYER_WENT_OVER_21`, `STATE_BOARD_PLAYING`, `STATE_BOARD_STOPPED`, `STATE_SHOWING_RESULT`). O número aleatório vem de um LFSR de 16 bits que roda a cada ciclo de clock e guarda o último valor entre 1 e 9. O intervalo de 1 segundo é contado a partir dos 50 MHz.
- **Display:** o pino `E` oscila a 500 Hz e um byte é enviado por período. Os dados mudam na subida de `E` e o LCD os lê na descida. Após a inicialização, o driver reenvia as duas linhas sem parar, então qualquer mudança no texto aparece em cerca de 0,1 s.

## Pinos

| Porta | Pino |
|-------|------|
| `system_clock` | E12 |
| `ps2_data` | V11 |
| `ps2_clock` | W12 |
| `lcd_data_bus<7>` a `<0>` | Y15, AB16, Y16, AA12, AB12, AB17, AB18, Y13 |
| `lcd_enable` | AB4 |
| `lcd_register_select` | Y14 |
| `lcd_read_write` | W13 |
