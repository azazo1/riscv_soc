# Snake app

这是一个纯 C 写的贪吃蛇应用, 直接写入 SDRAM framebuffer.

## Build

```shell
just build-app-snake
```

输出:

```text
build/apps/snake/snake.bin
```

上板时把 `snake.bin` 放到 FAT32 SD 卡根目录, 文件名改为 `INIT.BIN`.

## Controls

按键映射采用 hjkl 风格.

| 按键 | 作用 |
| --- | --- |
| `KEY0` | `h`, left |
| `KEY1` | `j`, down, start |
| `KEY2` | `k`, up, start |
| `KEY3` | `l`, right |
| `SW0` | pause |

开始前会进入难度选择界面, `h` 和 `l` 切换难度, `j` 或 `k` 开始游戏. 失败后再次按 `j` 或 `k` 回到难度选择.

## Test

```shell
just test-rv32i-soc-snake-app
```
