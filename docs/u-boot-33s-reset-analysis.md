# AR9344 U-Boot 33 秒自动复位分析

## 镜像身份

- 文件大小：`0x40000`（262,144 字节）
- SHA-256：`1dd832f5b5a8221819c7008babfeb63f9c1bbf26abfb389f02eadd61edb57e8a`
- 架构：大端 MIPS32，原始 U-Boot 镜像
- 链接基址：`0x9f000000`
- PIC 全局指针：`$gp = 0x9f02d3f0`

## 结论

自动启动与人工中断启动之间存在一个确定的硬件状态差异：**GPIO15**。

U-Boot 板级初始化先把 GPIO15 配置成输出并拉低。只有用户按键中断 autoboot 时，主循环才把 GPIO15 拉高；无人值守路径直接执行 `bootcmd`，不会做这个操作。

这与现象完全对应：GPIO15 保持低电平时，板外的复位监控器约 33 秒后复位整机；按键中断时 GPIO15 被拉高，监控被禁止或收到启动确认，随后选择 OP/OpenWrt 可以长期运行。

静态镜像只能证明 GPIO15 是差异点，不能单凭二进制区分它连接的是独立 watchdog 芯片还是管理 MCU；需要原理图或示波器确认外部器件类型。

## 关键反汇编证据

### 1. 板级初始化把 GPIO15 拉低

函数约位于 `0x9f017474`，相关代码位于：

- `0x9f0176a4`：加载 GPIO KSEG1 基址 `0xb8040000`
- `0x9f0176ac`：写 `GPIO_OE = 0`
- `0x9f0176bc`～`0x9f0176c0`：将 `GPIO_OE` 设为 `0x00000300`
- `0x9f017704`～`0x9f017714`：向 `GPIO_SET`（`0xb804000c`）加入 `0x00783000`
- `0x9f017718`～`0x9f01772c`：向 `GPIO_CLEAR`（`0xb8040010`）加入 `0x0000800f`

AR934x 的 GPIO OE 极性反转：OE 位为 0 表示输出。因此 `GPIO_OE=0x300` 时 GPIO15 已是输出；`GPIO_CLEAR` 的 `0x8000` 随后把 GPIO15 拉低。

### 2. 按键中断路径把 GPIO15 拉高

主循环/abortboot 逻辑位于 `0x9f012c5c`：

- `0x9f012d4c`：轮询串口字符
- `0x9f012d68`～`0x9f012d74`：检测到字符后读走字符，并令中断标志 `$s2=1`
- `0x9f012dc8`：若 `$s2=0`（无人按键），跳过 GPIO 操作，转到自动启动
- `0x9f012dd0`～`0x9f012de4`：人工中断时清除 `GPIO_OE` 的 bit 15，保证 GPIO15 为输出
- `0x9f012de8`～`0x9f012df4`：向 `GPIO_SET` 写入 bit 15，将 GPIO15 拉高
- `0x9f012e00`～`0x9f012e0c`：无人按键路径直接执行 `run_command(bootcmd, 3)`

因此人工 OP 与自动 `bootcmd` 的差异发生在执行具体启动命令之前。`bootopenwrt` 和 `bootstock` 的内容并不是 33 秒差异的根因。

## 已排除项目

### AR934x 内置 watchdog

AR934x reset block 中：

- `0xb8060008`：WDOG_CTRL
- `0xb806000c`：WDOG counter

整个 U-Boot 可执行区没有对这两个地址的读写。镜像确实访问了同一 reset block 的 `0xb806001c`（reset-module 寄存器）和 `0xb8060090`（revision ID），但那不是 watchdog 控制/计数器。

结合实机在 U-Boot prompt 读到 `0xb8060008/0x0c = 0/0`，33 秒复位不是这个 SoC watchdog。

### 环境状态变量

- `activeregion`、`f_upgrade2_addr`、`booting_state`、`wifi_enable`、`uboot_version` 确实被厂商定制 `bootm` 使用。
- `activeregion=2` 时会从 `f_upgrade2_addr` 读取备用镜像地址；镜像校验失败时可切换 region。
- `booting_state` 只在值为 `1` 时被推进到 `2` 并保存，没有 30 秒计时或复位逻辑。
- `fwupgrade`、`standbyversion`、`boot_T1_threshold`、`boot_T2_threshold`、`bootopenwrt`、`bootstock`、`OP`、`openwrt` 和 `stock` 均不存在于这份 U-Boot 可执行镜像的字符串中；它们属于独立环境分区或上层系统数据，不能触发这里的定时复位。

## 最小风险验证

人工按键中断 autoboot 后，先只读：

```text
md.l 0xb8040000 5
md.l 0xb8060008 2
```

预期：

- `0xb8040000` 的 bit 15 为 0（GPIO15 是输出）；
- `0xb8040004` 的 bit 15 通常为 1（实际引脚已被人工路径拉高，具体读回受板级电路影响）；
- `0xb8060008` 的低两位为 0，bit 31 也应为 0；`0xb806000c` 不呈现活动的内部 watchdog 倒计时。

验证自动启动修复时，只需复制人工路径中的安全 SET 写入：

```text
setenv bootcmd 'mw.l 0xb804000c 0x00008000 1; run bootopenwrt'
printenv bootcmd
saveenv
reset
```

重启后不要按键，观察至少 90 秒。如果不再复位，即可直接确认 GPIO15 是外部复位监控的禁止/确认线。

这里不需要覆盖整个 `GPIO_OE` 寄存器：板级初始化已经将 GPIO15 配成输出。只写 `GPIO_SET` 的单一 bit 掩码，风险低于把 `0xb8040000` 整字写回。

如需恢复：

```text
setenv bootcmd 'run bootopenwrt'
saveenv
```

## 长期修复

优先保留上述 U-Boot 环境修复，因为它在 Linux 接管前就解除外部复位监控，并且不修改 U-Boot 分区。

若要在 OpenWrt 侧加第二层保障，可先确认 GPIO15 未被其他驱动占用，然后在设备树的 GPIO 控制器下加入 GPIO hog，使其在 GPIO 驱动 probe 时立即输出高电平：

```dts
external_reset_inhibit {
    gpio-hog;
    gpios = <15 GPIO_ACTIVE_HIGH>;
    output-high;
    line-name = "external-reset-inhibit";
};
```

不建议直接刷写补丁版 U-Boot。若必须修改 bootloader，应把同样的 GPIO15 输出高操作移到公共的自动启动前置路径，而不是只改 `bootm` 或 region 状态机；任何 U-Boot 分区写入前都应保留完整 256 KiB 原始镜像、环境分区和全 Flash 备份，并准备 SPI 编程器恢复。
