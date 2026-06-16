#include "rv32i_soc.h"

#define APP_LOAD_ADDR 0x02010000u
#define APP_MAX_SIZE  0x00100000u

#define SD_CMD0   0u
#define SD_CMD8   8u
#define SD_CMD17  17u
#define SD_CMD55  55u
#define SD_CMD58  58u
#define SD_ACMD41 41u

static u8 sector[512];
static u32 partition_lba;
static u32 first_fat_sector;
static u32 first_data_sector;
static u32 root_cluster;
static u8 sectors_per_cluster;
static u8 sectors_per_cluster_shift;
static u8 sd_is_block_addr;

static u16 rd16(const u8 *p)
{
    return (u16)p[0] | ((u16)p[1] << 8);
}

static u32 rd32(const u8 *p)
{
    return (u32)p[0] | ((u32)p[1] << 8) | ((u32)p[2] << 16) | ((u32)p[3] << 24);
}

static void led_error(u32 code)
{
    rv32i_led_write(code);
    while (1) {
    }
}

static void put_hex8(u32 value)
{
    rv32i_uart_put_hex4(value >> 4);
    rv32i_uart_put_hex4(value);
}

static void put_hex32(u32 value)
{
    put_hex8(value >> 24);
    put_hex8(value >> 16);
    put_hex8(value >> 8);
    put_hex8(value);
}

static void boot_ok(const char *text)
{
    rv32i_uart_puts("boot ok ");
    rv32i_uart_puts(text);
    rv32i_uart_putc('\n');
}

static void boot_step(const char *text)
{
    rv32i_uart_puts("boot step ");
    rv32i_uart_puts(text);
    rv32i_uart_putc('\n');
}

#define boot_ok_hex(text, value) \
    do { \
        rv32i_uart_puts("boot ok "); \
        rv32i_uart_puts(text); \
        rv32i_uart_putc(' '); \
        put_hex32(value); \
        rv32i_uart_putc('\n'); \
    } while (0)

static void fail(const char *text, u32 code)
{
    rv32i_uart_puts("boot fail ");
    rv32i_uart_puts(text);
    rv32i_uart_putc(' ');
    put_hex8(code);
    rv32i_uart_putc('\n');
    led_error(code);
}

static void spi_idle_clocks(void)
{
    u32 i;

    rv32i_spi_set_cs(1u);
    for (i = 0; i < 10u; i++) {
        (void)rv32i_spi_transfer(0xffu);
    }
}

static u8 sd_cmd(u8 cmd, u32 arg, u8 crc)
{
    u32 i;
    u8 r1;

    rv32i_spi_transfer((u8)(0x40u | cmd));
    rv32i_spi_transfer((u8)(arg >> 24));
    rv32i_spi_transfer((u8)(arg >> 16));
    rv32i_spi_transfer((u8)(arg >> 8));
    rv32i_spi_transfer((u8)arg);
    rv32i_spi_transfer(crc);

    for (i = 0; i < 8u; i++) {
        r1 = rv32i_spi_transfer(0xffu);
        if ((r1 & 0x80u) == 0u) {
            return r1;
        }
    }

    return 0xffu;
}

static void sd_deselect(void)
{
    rv32i_spi_set_cs(1u);
    (void)rv32i_spi_transfer(0xffu);
}

static u8 sd_cmd_once(u8 cmd, u32 arg, u8 crc)
{
    u8 r1;

    rv32i_spi_set_cs(0u);
    r1 = sd_cmd(cmd, arg, crc);
    sd_deselect();
    return r1;
}

static void sd_init(void)
{
    u32 i;
    u8 r1;
    u8 ocr0;

    boot_step("sd-div-slow");
    rv32i_spi_set_div(63u);
    boot_step("sd-idle");
    spi_idle_clocks();

    boot_step("cmd0");
    rv32i_spi_set_cs(0u);
    r1 = sd_cmd(SD_CMD0, 0u, 0x95u);
    sd_deselect();
    if (r1 != 0x01u) {
        fail("cmd0", r1);
    }
    boot_ok("cmd0");

    boot_step("cmd8");
    rv32i_spi_set_cs(0u);
    r1 = sd_cmd(SD_CMD8, 0x000001aau, 0x87u);
    if (r1 != 0x01u) {
        sd_deselect();
        fail("cmd8", r1);
    }
    (void)rv32i_spi_transfer(0xffu);
    (void)rv32i_spi_transfer(0xffu);
    if (rv32i_spi_transfer(0xffu) != 0x01u) {
        sd_deselect();
        fail("cmd8-v", 8u);
    }
    if (rv32i_spi_transfer(0xffu) != 0xaau) {
        sd_deselect();
        fail("cmd8-p", 8u);
    }
    sd_deselect();
    boot_ok_hex("cmd8", r1);

    boot_step("acmd41");
    for (i = 0; i < 20000u; i++) {
        r1 = sd_cmd_once(SD_CMD55, 0u, 0x01u);
        if (r1 > 0x01u) {
            fail("cmd55", r1);
        }

        r1 = sd_cmd_once(SD_ACMD41, 0x40000000u, 0x01u);
        if (r1 == 0u) {
            break;
        }
    }
    if (r1 != 0u) {
        fail("acmd41", r1);
    }
    boot_ok_hex("acmd41", i);

    boot_step("cmd58");
    rv32i_spi_set_cs(0u);
    r1 = sd_cmd(SD_CMD58, 0u, 0x01u);
    if (r1 != 0u) {
        sd_deselect();
        fail("cmd58", r1);
    }
    ocr0 = rv32i_spi_transfer(0xffu);
    (void)rv32i_spi_transfer(0xffu);
    (void)rv32i_spi_transfer(0xffu);
    (void)rv32i_spi_transfer(0xffu);
    sd_deselect();

    sd_is_block_addr = (ocr0 & 0x40u) != 0u;
    boot_ok_hex("ocr0", ocr0);
    boot_step("sd-div-fast");
    rv32i_spi_set_div(5u);
}

static void sd_read_sector(u32 lba, u8 *out)
{
    u32 i;
    u32 arg;
    u8 r1;
    u8 token;

    if (sd_is_block_addr) {
        arg = lba;
    } else {
        arg = lba << 9;
    }

    rv32i_spi_set_cs(0u);
    r1 = sd_cmd(SD_CMD17, arg, 0x01u);
    if (r1 != 0u) {
        sd_deselect();
        fail("cmd17", r1);
    }

    for (i = 0; i < 20000u; i++) {
        token = rv32i_spi_transfer(0xffu);
        if (token == 0xfeu) {
            break;
        }
    }
    if (token != 0xfeu) {
        sd_deselect();
        fail("token", token);
    }

    for (i = 0; i < 512u; i++) {
        out[i] = rv32i_spi_transfer(0xffu);
    }
    (void)rv32i_spi_transfer(0xffu);
    (void)rv32i_spi_transfer(0xffu);
    sd_deselect();
}

static u8 calc_shift(u8 value)
{
    u8 shift;
    u8 tmp;

    shift = 0u;
    tmp = value;
    while (tmp > 1u) {
        if ((tmp & 1u) != 0u) {
            fail("cluster", tmp);
        }
        tmp >>= 1;
        shift++;
    }
    return shift;
}

static u32 cluster_lba(u32 cluster)
{
    return first_data_sector + ((cluster - 2u) << sectors_per_cluster_shift);
}

static u32 next_cluster(u32 cluster)
{
    u32 offset;
    u32 fat_lba;
    u32 entry_offset;

    offset = cluster << 2;
    fat_lba = first_fat_sector + (offset >> 9);
    entry_offset = offset & 0x1ffu;

    sd_read_sector(fat_lba, sector);
    return rd32(&sector[entry_offset]) & 0x0fffffffu;
}

static u8 is_fat32_bpb(const u8 *p)
{
    if (p[510] != 0x55u || p[511] != 0xaau) return 0u;
    if (rd16(&p[11]) != 512u) return 0u;
    if (p[13] == 0u) return 0u;
    if (rd32(&p[36]) == 0u) return 0u;
    if (rd32(&p[44]) < 2u) return 0u;
    return 1u;
}

static void parse_partition(void)
{
    u8 type;

    partition_lba = 0u;
    if (is_fat32_bpb(sector)) {
        return;
    }

    if (sector[510] != 0x55u || sector[511] != 0xaau) {
        fail("mbr", 1u);
    }

    type = sector[450];
    if (type == 0u) {
        fail("mbr", 2u);
    }
    partition_lba = rd32(&sector[454]);
}

static void parse_fat32(void)
{
    u16 bytes_per_sector;
    u16 reserved;
    u8 num_fats;
    u32 fat_size;

    bytes_per_sector = rd16(&sector[11]);
    if (bytes_per_sector != 512u) {
        fail("bps", bytes_per_sector);
    }

    sectors_per_cluster = sector[13];
    if (sectors_per_cluster == 0u) {
        fail("spc", 0u);
    }
    sectors_per_cluster_shift = calc_shift(sectors_per_cluster);

    reserved = rd16(&sector[14]);
    num_fats = sector[16];
    fat_size = rd32(&sector[36]);
    root_cluster = rd32(&sector[44]);

    if (fat_size == 0u || root_cluster < 2u) {
        fail("fat32", 0u);
    }

    first_fat_sector = partition_lba + reserved;
    first_data_sector = first_fat_sector + fat_size * num_fats;
}

static u8 is_init_bin_entry(const u8 *entry)
{
    if (entry[0] != 'I') return 0u;
    if (entry[1] != 'N') return 0u;
    if (entry[2] != 'I') return 0u;
    if (entry[3] != 'T') return 0u;
    if (entry[4] != ' ') return 0u;
    if (entry[5] != ' ') return 0u;
    if (entry[6] != ' ') return 0u;
    if (entry[7] != ' ') return 0u;
    if (entry[8] != 'B') return 0u;
    if (entry[9] != 'I') return 0u;
    if (entry[10] != 'N') return 0u;
    return 1u;
}

static u8 find_init_bin(u32 *start_cluster, u32 *file_size)
{
    u32 cluster;
    u8 s;
    u32 i;
    const u8 *entry;
    u8 attr;

    cluster = root_cluster;

    while (cluster < 0x0ffffff8u) {
        for (s = 0u; s < sectors_per_cluster; s++) {
            sd_read_sector(cluster_lba(cluster) + s, sector);

            for (i = 0u; i < 512u; i += 32u) {
                entry = &sector[i];
                if (entry[0] == 0x00u) {
                    return 0u;
                }
                if (entry[0] == 0xe5u) {
                    continue;
                }

                attr = entry[11];
                if (attr == 0x0fu || (attr & 0x08u) != 0u) {
                    continue;
                }

                if (is_init_bin_entry(entry)) {
                    *start_cluster = ((u32)rd16(&entry[20]) << 16) | rd16(&entry[26]);
                    *file_size = rd32(&entry[28]);
                    return 1u;
                }
            }
        }

        cluster = next_cluster(cluster);
    }

    return 0u;
}

static void load_file(u32 start_cluster, u32 file_size)
{
    u32 cluster;
    u32 remaining;
    u32 copy_count;
    u32 i;
    u8 s;
    u8 *dst;

    if (file_size == 0u || file_size > APP_MAX_SIZE) {
        fail("size", file_size);
    }

    cluster = start_cluster;
    remaining = file_size;
    dst = (u8 *)APP_LOAD_ADDR;

    while (cluster < 0x0ffffff8u && remaining != 0u) {
        for (s = 0u; s < sectors_per_cluster && remaining != 0u; s++) {
            sd_read_sector(cluster_lba(cluster) + s, sector);

            copy_count = remaining;
            if (copy_count > 512u) {
                copy_count = 512u;
            }

            for (i = 0u; i < copy_count; i++) {
                dst[i] = sector[i];
            }

            dst += copy_count;
            remaining -= copy_count;
        }

        if (remaining != 0u) {
            cluster = next_cluster(cluster);
        }
    }

    if (remaining != 0u) {
        fail("chain", remaining);
    }
}

int main(void)
{
    u32 start_cluster;
    u32 file_size;
    void (*app)(void);

    rv32i_led_write(0x100u);
    rv32i_uart_puts("boot\n");

    sd_init();
    boot_ok("sd");

    sd_read_sector(0u, sector);
    parse_partition();
    boot_ok_hex("part", partition_lba);
    sd_read_sector(partition_lba, sector);
    parse_fat32();
    boot_ok("fat");

    if (!find_init_bin(&start_cluster, &file_size)) {
        fail("init", 0u);
    }
    boot_ok_hex("init", file_size);

    load_file(start_cluster, file_size);
    boot_ok("load");

    rv32i_uart_puts("jump\n");
    rv32i_led_write(0x200u);

    app = (void (*)(void))APP_LOAD_ADDR;
    app();

    fail("ret", 0u);
    return 0;
}
