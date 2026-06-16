# 自动售货机固件

这是一个直接放进 ROM 运行的 C 语言自动售货机演示程序. 它不经过 SD bootloader, 不放在 `apps/`, 也不访问 SDRAM.

## 操作方式

- `SW9`: 板级硬复位. `SW9=1` 时 CPU 复位, `SW9=0` 时运行.
- `SW0`: 售货机程序运行开关. `SW0=0` 时清空当前订单, `SW0=1` 时开始响应按键.
- `KEY0`: 选择商品. 空闲时按下会在 A, B, C 之间切换; 投币中按下会退币.
- `KEY1`: 投入 1 角。
- `KEY2`: 投入 5 角。
- `KEY3`: 投入 10 角。

KEY 是低有效, 也就是按下时读到 `0`.

如果 HEX 显示 000000 且按键没有反应, 先确认 `SW0=1`.

## 商品价格

金额单位统一使用角:

| 商品 | 价格 |
| --- | --- |
| A | 9 角 |
| B | 12 角 |
| C | 23 角 |

## 显示约定

- `LEDR[0]`: 选中商品 A.
- `LEDR[1]`: 选中商品 B.
- `LEDR[2]`: 选中商品 C.
- `LEDR[9]`: 程序处于工作状态, 也就是 `SW0=1`.
- `HEX0..HEX1`: 当前投入金额; 成交或退币后显示找零/退币金额.
- `HEX2..HEX3`: 当前商品价格.
- `HEX4`: 订单状态. `0` 空闲, `1` 投币中, `2` 成交, `3` 退币.
- `HEX5`: 固定显示 `0`.

## 构建

生成 ROM hex:

```sh
just firmware-selfsale
```

仿真测试:

```sh
just test-rv32i-soc-selfsale-rom
```

## 串口输出

- 启动后输出 `selfsale boot`.
- `SW0=0` 等待运行开关时输出一次 `wait sw0`.
- `SW0` 进入运行时输出 `run`.
- 选择商品时输出 `select A`, `select B`, `select C`.
- 投币时输出 `coin 1`, `coin 5`, `coin 10`.
- 成交时输出 `done`, 退币时输出 `refund`.

如果要把这个固件烧进 ROM, 需要在仿真或顶层实例化时把 `ROM_FILE` 指向:

```text
firmware/selfsale/selfsale.hex
```

这个固件只使用 ROM, 低地址 boot RAM 栈, 以及 GPIO/HEX/LED/KEY MMIO。
