# 红米 AX3000（RA81）刷入 ImmortalWrt 完整教程

本仓库把 [hzyitc/openwrt-redmi-ax3000](https://github.com/hzyitc/openwrt-redmi-ax3000)
里对红米 AX3000（RA81，含小米 CR880x M79/M81）的支持，移植到了 ImmortalWrt
（`qualcommax` 目标的 `ipq50xx` 子目标，内核 6.18 + DSA 交换机框架）。

固件通过 GitHub Actions 构建，无需本地编译环境。

---

## 0. 硬件与固件规格

| 项目 | 参数 |
| --- | --- |
| SoC | 高通 IPQ5000（与 IPQ5018 同族） |
| 交换芯片 | QCA8337（外置，DSA 驱动 `qca8337`） |
| 无线 | 2.4G：IPQ5000 集成；5G：QCN6102（`qcn6122` 驱动通路） |
| 存储 | SPI NAND，双系统 `rootfs` / `rootfs_1`（U-Boot 用 `flag_boot_rootfs` 切槽） |
| 内存 | 256 MB |
| 有线 | 1×WAN + 3×LAN（均为千兆） |
| 设备树 compatible | `redmi,ax3000` |

固件文件名为
`immortalwrt-qualcommax-ipq50xx-redmi_ax3000-squashfs-factory.ubi`，
它是一个**完整的 UBI 镜像**（卷 0 内核、卷 1 根文件系统），既可用于 U-Boot 刷写，
也可用于系统内 `sysupgrade`。

---

## 1. 构建固件（GitHub Actions）

工作流：`.github/workflows/build-redmi-ax3000.yml`

触发方式二选一：

* 推送到本仓库的 `ax3000` 分支（自动触发）；
* 在仓库 **Actions → Build ImmortalWrt for Redmi AX3000 (RA81) → Run workflow** 手动触发。

构建完成后，在该次运行的 **Artifacts** 里下载 `immortalwrt-redmi_ax3000`，
里面就是 `…-redmi_ax3000-squashfs-factory.ubi`。

> 首次构建约 1.5–3 小时（会在线拉取 feeds 与工具链），之后的构建会走缓存。

---

## 2. 刷机总览

红米 AX3000 出厂是小米的**双系统（A/B）**布局：

| mtd | 名称 | 说明 |
| --- | --- | --- |
| mtd1 | `0:mibib` | 分区表（大分区 U-Boot 会改这里） |
| mtd10 | `0:appsblenv` | U-Boot 环境变量 |
| mtd11 / mtd12 | `0:appsbl` / `0:appsbl_1` | 双 U-Boot |
| mtd15 | 板级数据 | 含 `wl_pa_type=`（决定 2.4G 校准档） |
| mtd18 / mtd19 | `rootfs` / `rootfs_1` | 两个系统槽（各含 kernel+rootfs） |
| — | `0:ART` | 校准/ MAC 数据 |

刷机就是把 OpenWrt/ImmortalWrt 的 UBI 写进 `rootfs` 或 `rootfs_1`，
再用 U-Boot 变量把启动槽切过去；两个槽互相独立，可以随时回退。

下面给出两种方式，**推荐方式一（免拆机）**。

---

## 3. 方式一：免拆机刷机（推荐）

> 思路参考 [yanchang.cc 的教程](https://yanchang.cc:8091/archives/hong-mi-ax3000-ra81-mian-chai-ji-kai-qi-sshshua-ru-openwrtjiao-cheng)：
> 先用 XMiR-Patcher 免拆开 SSH，再写入“大分区 + 不死 U-Boot”，最后把系统写进
> `rootfs_1`/`rootfs` 并重启。

### 3.1 开启 SSH

1. 电脑与路由器都接入同一网络，确保电脑能 ping 通路由器。
2. 下载 [openwrt-xiaomi/xmir-patcher](https://github.com/openwrt-xiaomi/xmir-patcher)
   （Code → Download ZIP，解压）。
   Windows 直接双击 `Run`；Linux / macOS 需 Python 3.8+ 与 openssl。
3. 运行脚本，确认默认网关是路由器 IP（不对就选 1 手动改）。
4. 脚本会识别设备型号并提示输入**小米网页管理密码**，回车后等约 3 分钟，
   看到 “SSH 开启成功” 即可输入 `0` 退出。
5. 现在用 `ssh root@<路由器IP>` 即可登录（密码同网页管理密码）。

> 只要还停留在原厂系统，随时可以用官方修复工具刷回原厂固件。

### 3.2 写入大分区 / 不死 U-Boot（强烈建议先做）

> 大分区 U-Boot（来自 qaqal）会把 `0:mibib` 换成更大的分区表，
> 需要时可在 U-Boot 网页面（192.168.10.1）救砖；同时系统可用空间从 ~18MB 提升到 ~80MB。

路由器联网后，在 SSH 里执行：

```sh
cd /tmp
# 下载 U-Boot 与大分区文件（也可以自己在电脑下载好再 scp 上来）
curl -L -o /tmp/MIBIB.bin   "http://home.yanchang.pw:12345/share/select?code=N68KW"
curl -L -o /tmp/APPSBL.bin  "http://home.yanchang.pw:12345/share/select?code=Y6342"
curl -L -o /tmp/APPSBL1.bin "http://home.yanchang.pw:12345/share/select?code=0A737"

# 写入对应分区
mtd write /tmp/MIBIB.bin   /dev/mtd1
mtd write /tmp/APPSBL.bin  /dev/mtd11
mtd write /tmp/APPSBL1.bin /dev/mtd12
```

写完**先不要重启**：此时原厂系统已经无法启动，必须接着刷新系统（下一步）。

> 如果你不想换 U-Boot，也可以跳过 3.2，直接从 3.3 刷入系统（只是可用空间较小）。

### 3.3 写入 ImmortalWrt

1. 在**电脑浏览器**手动下载刚才构建出的固件：
   `immortalwrt-qualcommax-ipq50xx-redmi_ax3000-squashfs-factory.ubi`

   > 原厂系统刷完引导后 DNS 常常失效，路由器内直接 `curl/wget` 会失败，
   > 所以推荐在电脑下载再用 scp 传进路由器。

2. 把固件传到路由器 `/tmp`：

   * macOS / Linux：
     ```sh
     scp immortalwrt-qualcommax-ipq50xx-redmi_ax3000-squashfs-factory.ubi root@<路由器IP>:/tmp/
     ```
   * Windows PowerShell（加 `-O` 强制用传统 SCP 协议）：
     ```powershell
     scp -O .\immortalwrt-qualcommax-ipq50xx-redmi_ax3000-squashfs-factory.ubi root@<路由器IP>:/tmp/
     ```

3. 在路由器 SSH 里执行下面这段（会自动判断当前系统槽，并刷进**另一个槽**）：

   ```sh
   FW=/tmp/immortalwrt-qualcommax-ipq50xx-redmi_ax3000-squashfs-factory.ubi

   # 查看当前是从哪个槽启动的
   cat /proc/cmdline
   mtd="$(grep -oE 'ubi.mtd=[a-zA-Z0-9_-]*' /proc/cmdline | cut -d'=' -f2)"

   if [ "$mtd" = "rootfs" ]; then
       # 当前是系统1，刷入系统2(mtd19)
       ubiformat /dev/mtd19 -f "$FW" -y
       nvram set flag_try_sys2_failed=0
       nvram set flag_boot_rootfs=1
       nvram set flag_last_success=1
       nvram commit
   elif [ "$mtd" = "rootfs_1" ]; then
       # 当前是系统2，刷入系统1(mtd18)
       ubiformat /dev/mtd18 -f "$FW" -y
       nvram set flag_try_sys1_failed=0
       nvram set flag_boot_rootfs=0
       nvram set flag_last_success=0
       nvram commit
   fi

   # 重启进入 ImmortalWrt
   reboot
   ```

4. 等 1–2 分钟，路由器启动后：
   * 管理地址：`http://192.168.1.1`
   * 用户名 `root`，密码为空

### 3.4 首次配置

1. 进入 `System → Administration` 设置 root 密码（保存后警告消失）。
2. 需要中文界面：`System → Software`，先 **Update lists**，
   搜索 `luci-i18n-base-zh-cn`（或列表中的 `base` 中文包）安装，刷新页面即可切换中文。
3. 自行配置 WAN / LAN、WiFi 等。

---

## 4. 方式二：UART + TFTP（原厂救砖 / 不装 XMiR-Patcher）

这是 hzyitc 仓库 README 里的官方方法，需要 USB-TTL 串口。

### 4.1 先让原厂系统恢复一次，并打开 UART

1. 连接 UART 与 LAN。
2. 从官网下载原厂固件（RA81：`miwifi_ra81_firmware_1dd69c_1.0.33.bin`）。
3. 用 `MIWIFIRepairTool`（本质是 TFTP 恢复）刷回原厂固件。
4. 按住 reset 上电直到系统灯闪烁，等待刷写完成。
5. 断电重上电，在串口里按任意键打断 U-Boot，执行：

   ```sh
   setenv boot_wait on
   setenv uart_en 1
   saveenv
   ```

### 4.2 在 U-Boot 中刷入 ImmortalWrt

把固件放入 TFTP 根目录，然后在 U-Boot 里：

```sh
# 本机(路由器)与 TFTP 服务器地址
setenv ipaddr 192.168.1.2
setenv serverip 192.168.1.1

# 下载固件到内存
tftpboot immortalwrt-qualcommax-ipq50xx-redmi_ax3000-squashfs-factory.ubi

# 写进系统 2 (rootfs_1)
flash rootfs_1
setenv flag_try_sys2_failed 0
setenv flag_boot_rootfs 1
setenv flag_last_success 1
saveenv

# 也可以改写成系统 1 (rootfs)：
#   flash rootfs
#   setenv flag_try_sys1_failed 0
#   setenv flag_boot_rootfs 0
#   setenv flag_last_success 0
#   saveenv

reset
```

重启后即为 ImmortalWrt（192.168.1.1，root 空密码）。

---

## 5. 系统内升级

ImmortalWrt 的 `sysupgrade` 会**写入另一个槽**并切换启动：

* 网页：`System → Backup / Flash Firmware → Flash image`，
  选择新构建的 `…-redmi_ax3000-squashfs-factory.ubi`。
* 命令行：`sysupgrade /tmp/…-redmi_ax3000-squashfs-factory.ubi`

升级脚本（`/lib/upgrade/mi_dualboot.sh`）会：
1. 根据 `/proc/cmdline` 判断当前槽，写入另一个 `rootfs`/`rootfs_1`；
2. 清除 `flag_try_sys*_failed`，设置 `flag_last_success` 与 `flag_ota_reboot`；
3. 新系统启动成功后，`/etc/init.d/uboot_env` 会固化 `flag_boot_success`。

如果新系统起不来，U-Boot 会依据 `flag_last_success` 回滚到旧槽。

---

## 6. 救砖 / 恢复出厂

* 若已刷大分区 U-Boot：**断电，按住 reset 键上电约 10 秒**，
  浏览器访问 `http://192.168.10.1` 进入 U-Boot 网页，
  可上传固件重新刷写或直接在网页里救砖。
* 若未换 U-Boot：可用小米官方 `MIWIFIRepairTool` 走 TFTP 恢复原厂固件
  （按住 reset 上电进入恢复模式）。

---

## 7. 移植实现说明与注意事项

已移植/新增的内容：

| 文件 | 说明 |
| --- | --- |
| `target/linux/qualcommax/dts/ipq5018-redmi-ax3000.dts` | 设备树（DSA 版本） |
| `target/linux/qualcommax/image/ipq50xx.mk` | `redmi_ax3000` 设备定义（UbiFit） |
| `target/linux/qualcommax/ipq50xx/base-files/…/02_network` | LAN/WAN 映射 |
| `target/linux/qualcommax/ipq50xx/base-files/…/01_leds` | 指示灯 |
| `target/linux/qualcommax/ipq50xx/base-files/…/11-ath11k-caldata` | 从 `0:ART` 提取 WiFi 校准 |
| `target/linux/qualcommax/ipq50xx/base-files/lib/upgrade/mi_dualboot.sh` | 双系统升级 |
| `target/linux/qualcommax/ipq50xx/base-files/etc/init.d/uboot_env` | 升级后维护 U-Boot 变量 |
| `package/firmware/ipq-wifi/` | `ipq-wifi-redmi_ax3000` 板级 BDF |
| `package/boot/uboot-tools/uboot-envtools/files/qualcommax_ipq50xx` | `0:appsblenv` 环境 |

刷机后请重点验证以下几点（首版移植，建议实机确认）：

1. **WiFi**：2.4G/5G 是否正常起来。板级 BDF 取自 hzyitc（`board-redmi_ax3000.ipq5018` /
   `.qcn6122`），通过目标自身上报的 `qmi-board-id`（M81 = 0x24，M79 = 0x10）匹配。
   若 Wi-Fi 不出来，可在 `dmesg` 里看 ath11k 的 “board” 相关日志。
2. **端口顺序**：LAN1/2/3 与 WAN 的对应关系（本移植依据 hzyitc：端口 1/2/3 = LAN1/2/3，
   端口 4 = WAN）。若插错口，只需调整 DTS 里 `ethernet-port@N` 的 `label`。
3. **MAC 地址**：取自 `0:ART` 偏移 0/6；若不正确，可调整 DTS 中 `macaddr_art_*` 的偏移。
4. **指示灯 / 按键**：system 灯（蓝/黄）、internet 灯、reset 键、mesh 键。

> 说明：hzyitc 仓库里还有一组 ath11k 补丁（从 devicetree / 文件系统读取 `board_id`），
> 用于在 M79/M81 之间动态选择板级数据。ImmortalWrt 主线没有这组补丁，本移植改用
> “让 ath11k 按目标上报的 board-id 匹配” 的方式，因此对正常的 RA81（M81）无需额外补丁。
