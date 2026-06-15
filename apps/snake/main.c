#include "rv32i_soc.h"

#define FB_WIDTH RV32I_VGA_FB_WIDTH
#define FB_HEIGHT RV32I_VGA_FB_HEIGHT
#define FB_WORDS (RV32I_VGA_FB_PIXELS / 4u)

#define CELL_SIZE 8u
#define GRID_WIDTH (FB_WIDTH / CELL_SIZE)
#define GRID_HEIGHT (FB_HEIGHT / CELL_SIZE)
#define SNAKE_MAX (GRID_WIDTH * GRID_HEIGHT)

#define DIR_LEFT 0u
#define DIR_DOWN 1u
#define DIR_UP 2u
#define DIR_RIGHT 3u

#define KEY_H 0u
#define KEY_J 1u
#define KEY_K 2u
#define KEY_L 3u

#define COLOR_BLACK 0x00u
#define COLOR_BG 0x04u
#define COLOR_GRID 0x25u
#define COLOR_SNAKE 0x1cu
#define COLOR_HEAD 0x3fu
#define COLOR_FOOD 0xe0u
#define COLOR_MENU 0x03u
#define COLOR_SELECT 0xfcu
#define COLOR_GAME_OVER 0xe4u
#define COLOR_WHITE 0xffu

static const u8 hex_seg[16] = {
    0x40u, 0x79u, 0x24u, 0x30u,
    0x19u, 0x12u, 0x02u, 0x78u,
    0x00u, 0x10u, 0x08u, 0x03u,
    0x46u, 0x21u, 0x06u, 0x0eu,
};

static u8 snake_x[SNAKE_MAX];
static u8 snake_y[SNAKE_MAX];
static u32 snake_len;
static u32 food_x;
static u32 food_y;
static u32 dir;
static u32 next_dir;
static u32 score;
static u32 rng_state = 0x1234abcdu;

static void delay_count(u32 count)
{
    volatile u32 i;

    for (i = 0u; i < count; i++) {
    }
}

static void show_hex24(u32 value)
{
    u32 digit0;
    u32 digit1;
    u32 digit2;
    u32 digit3;
    u32 digit4;
    u32 digit5;

    digit0 = hex_seg[value & 0x0fu];
    digit1 = hex_seg[(value >> 4) & 0x0fu];
    digit2 = hex_seg[(value >> 8) & 0x0fu];
    digit3 = hex_seg[(value >> 12) & 0x0fu];
    digit4 = hex_seg[(value >> 16) & 0x0fu];
    digit5 = hex_seg[(value >> 20) & 0x0fu];

    HEX_LOW = digit0 | (digit1 << 8) | (digit2 << 16) | (digit3 << 24);
    HEX_HIGH = digit4 | (digit5 << 8);
}

static u32 key_is_down(u32 key_bits, u32 bit)
{
    return (key_bits & (1u << bit)) == 0u;
}

static u32 read_key_edge(void)
{
    static u32 last_key = 0x0fu;
    u32 now_key;
    u32 edge;

    now_key = KEY & 0x0fu;
    edge = last_key & ~now_key;
    last_key = now_key;

    return edge;
}

static u32 rng_next(void)
{
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 17;
    rng_state ^= rng_state << 5;
    return rng_state;
}

static u32 color_word(u8 color)
{
    u32 value;

    value = color;
    return value | (value << 8) | (value << 16) | (value << 24);
}

static void fill_screen(u8 color)
{
    volatile u32 *fb;
    u32 packed;
    u32 i;

    fb = (volatile u32 *)RV32I_VGA_FB_BASE;
    packed = color_word(color);

    for (i = 0u; i < FB_WORDS; i++) {
        fb[i] = packed;
    }
}

static void draw_rect(u32 x, u32 y, u32 w, u32 h, u8 color)
{
    volatile u32 *fb;
    u32 packed;
    u32 row;
    u32 col;

    fb = (volatile u32 *)RV32I_VGA_FB_BASE;
    packed = color_word(color);

    for (row = 0u; row < h; row++) {
        u32 base;

        base = (y + row) * (FB_WIDTH / 4u) + (x / 4u);
        for (col = 0u; col < w; col += 4u) {
            fb[base + (col / 4u)] = packed;
        }
    }
}

static void draw_cell(u32 cell_x, u32 cell_y, u8 color)
{
    u32 px;
    u32 py;

    px = cell_x * CELL_SIZE;
    py = cell_y * CELL_SIZE;
    draw_rect(px, py, CELL_SIZE, CELL_SIZE, color);
}

static u32 snake_has_cell(u32 x, u32 y)
{
    u32 i;

    for (i = 0u; i < snake_len; i++) {
        if ((snake_x[i] == x) && (snake_y[i] == y)) {
            return 1u;
        }
    }

    return 0u;
}

static void place_food(void)
{
    u32 tries;
    u32 x;
    u32 y;

    for (tries = 0u; tries < 200u; tries++) {
        x = 1u + (rng_next() % (GRID_WIDTH - 2u));
        y = 1u + (rng_next() % (GRID_HEIGHT - 2u));

        if (snake_has_cell(x, y) == 0u) {
            food_x = x;
            food_y = y;
            return;
        }
    }

    food_x = 1u;
    food_y = 1u;
}

static void draw_menu(u32 difficulty)
{
    u32 i;

    fill_screen(COLOR_MENU);

    for (i = 0u; i < 3u; i++) {
        u32 x;
        u32 y;
        u32 h;
        u8 color;

        x = 28u + i * 40u;
        y = 72u - i * 16u;
        h = 24u + i * 16u;
        color = (i == difficulty) ? COLOR_SELECT : COLOR_GRID;
        draw_rect(x, y, 24u, h, color);
        draw_rect(x + 4u, y + 4u, 16u, h - 8u, COLOR_MENU);
    }

    draw_rect(16u, 16u, 128u, 8u, COLOR_WHITE);
    draw_rect(16u, 32u, 128u, 8u, COLOR_WHITE);
    LEDR = 1u << difficulty;
    show_hex24(difficulty + 1u);
}

static u32 select_difficulty(void)
{
    u32 difficulty;

    difficulty = 1u;
    draw_menu(difficulty);

    while (1) {
        u32 edge;

        edge = read_key_edge();
        if (edge & (1u << KEY_H)) {
            if (difficulty > 0u) {
                difficulty--;
            }
            draw_menu(difficulty);
        }
        if (edge & (1u << KEY_L)) {
            if (difficulty < 2u) {
                difficulty++;
            }
            draw_menu(difficulty);
        }
        if ((edge & (1u << KEY_J)) || (edge & (1u << KEY_K))) {
            return difficulty;
        }

        delay_count(20000u);
    }
}

static void reset_game(void)
{
    u32 start_x;
    u32 start_y;

    start_x = GRID_WIDTH / 2u;
    start_y = GRID_HEIGHT / 2u;

    snake_len = 4u;
    snake_x[0] = (u8)start_x;
    snake_y[0] = (u8)start_y;
    snake_x[1] = (u8)(start_x - 1u);
    snake_y[1] = (u8)start_y;
    snake_x[2] = (u8)(start_x - 2u);
    snake_y[2] = (u8)start_y;
    snake_x[3] = (u8)(start_x - 3u);
    snake_y[3] = (u8)start_y;

    dir = DIR_RIGHT;
    next_dir = DIR_RIGHT;
    score = 0u;
    place_food();
}

static void update_direction(void)
{
    u32 key_bits;

    key_bits = KEY & 0x0fu;

    if (key_is_down(key_bits, KEY_H) && (dir != DIR_RIGHT)) {
        next_dir = DIR_LEFT;
    }
    if (key_is_down(key_bits, KEY_J) && (dir != DIR_UP)) {
        next_dir = DIR_DOWN;
    }
    if (key_is_down(key_bits, KEY_K) && (dir != DIR_DOWN)) {
        next_dir = DIR_UP;
    }
    if (key_is_down(key_bits, KEY_L) && (dir != DIR_LEFT)) {
        next_dir = DIR_RIGHT;
    }
}

static void draw_game(void)
{
    u32 i;

    fill_screen(COLOR_BG);

    for (i = 0u; i < GRID_WIDTH; i++) {
        draw_cell(i, 0u, COLOR_GRID);
        draw_cell(i, GRID_HEIGHT - 1u, COLOR_GRID);
    }

    for (i = 0u; i < GRID_HEIGHT; i++) {
        draw_cell(0u, i, COLOR_GRID);
        draw_cell(GRID_WIDTH - 1u, i, COLOR_GRID);
    }

    draw_cell(food_x, food_y, COLOR_FOOD);

    for (i = 1u; i < snake_len; i++) {
        draw_cell(snake_x[i], snake_y[i], COLOR_SNAKE);
    }
    draw_cell(snake_x[0], snake_y[0], COLOR_HEAD);

    show_hex24(score);
}

static u32 move_snake(void)
{
    u32 new_x;
    u32 new_y;
    u32 grow;
    u32 i;

    dir = next_dir;
    new_x = snake_x[0];
    new_y = snake_y[0];

    if (dir == DIR_LEFT) {
        new_x--;
    } else if (dir == DIR_RIGHT) {
        new_x++;
    } else if (dir == DIR_UP) {
        new_y--;
    } else {
        new_y++;
    }

    if ((new_x == 0u) || (new_y == 0u) ||
        (new_x == (GRID_WIDTH - 1u)) || (new_y == (GRID_HEIGHT - 1u))) {
        return 0u;
    }

    grow = ((new_x == food_x) && (new_y == food_y));

    for (i = 0u; i < snake_len; i++) {
        if ((snake_x[i] == new_x) && (snake_y[i] == new_y)) {
            if ((grow != 0u) || (i + 1u < snake_len)) {
                return 0u;
            }
        }
    }

    if ((grow != 0u) && (snake_len < SNAKE_MAX)) {
        snake_len++;
    }

    for (i = snake_len - 1u; i > 0u; i--) {
        snake_x[i] = snake_x[i - 1u];
        snake_y[i] = snake_y[i - 1u];
    }

    snake_x[0] = (u8)new_x;
    snake_y[0] = (u8)new_y;

    if (grow != 0u) {
        score++;
        place_food();
    }

    return 1u;
}

static void show_game_over(void)
{
    fill_screen(COLOR_GAME_OVER);
    draw_rect(24u, 48u, 112u, 24u, COLOR_BLACK);
    draw_rect(32u, 56u, 96u, 8u, COLOR_WHITE);
    LEDR = 0x200u | (score & 0x0ffu);
    show_hex24(score);
}

static void wait_for_restart(void)
{
    show_game_over();

    while (1) {
        u32 edge;

        edge = read_key_edge();
        if ((edge & (1u << KEY_J)) || (edge & (1u << KEY_K))) {
            return;
        }

        delay_count(20000u);
    }
}

static u32 difficulty_delay(u32 difficulty)
{
    if (difficulty == 0u) {
        return 150000u;
    }
    if (difficulty == 1u) {
        return 90000u;
    }
    return 50000u;
}

int main(void)
{
    u32 difficulty;
    u32 wait_ticks;

    rv32i_uart_puts("snake app\n");

    while (1) {
        difficulty = select_difficulty();
        wait_ticks = difficulty_delay(difficulty);
        reset_game();
        draw_game();

        while (1) {
            if (SW & 1u) {
                LEDR = 0x100u | (score & 0x0ffu);
                delay_count(40000u);
                continue;
            }

            update_direction();
            delay_count(wait_ticks);
            update_direction();

            if (move_snake() == 0u) {
                wait_for_restart();
                break;
            }

            LEDR = 0x040u | ((score + 1u) & 0x03fu);
            draw_game();
        }
    }
}
