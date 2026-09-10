# VMStart 16 引擎扩展方案

## 一、引擎列表（全部 GPLv2）

| # | 引擎 | 系统/平台 | 可执行文件发现路径 |
|---|------|-----------|-------------------|
| 1 | QEMU | 通用全架构 | `qemu-system-*` |
| 2 | Mini vMac | 早期 68k Mac | `Mini vMac.app` |
| 3 | BasiliskII | Mac II 系列 | `BasiliskII.app` |
| 4 | SheepShaver | PowerPC Mac | `SheepShaver.app` |
| 5 | DOSBox | MS-DOS | `DOSBox.app`, `dosbox` |
| 6 | DOSBox-X | MS-DOS/Windows 9x | `DOSBox-X.app`, `dosbox-x` |
| 7 | PCem | IBM PC | `pcem` |
| 8 | 86Box | IBM PC | `86Box.app`, `86Box` |
| 9 | VICE | Commodore 64/128/PET/VIC-20 | `x64sc`, `VICE.app` |
| 10 | FS-UAE | Amiga | `FS-UAE.app`, `fs-uae` |
| 11 | Hatari | Atari ST/STE/TT/Falcon | `Hatari.app`, `hatari` |
| 12 | OpenMSX | MSX | `openmsx`, `OpenMSX.app` |
| 13 | Fuse | ZX Spectrum | `fuse`, `Fuse.app` |
| 14 | ScummVM | 冒险游戏引擎 | `ScummVM.app`, `scummvm` |
| 15 | Mednafen | 多主机（PS1/Saturn等） | `mednafen` |
| 16 | ARAnyM | Atari ST/TT/Falcon VM | `aranym`, `ARAnyM.app` |

## 二、机器类型命名规则与路由

为每个引擎分配一个**机器类型前缀**，`VMStartEngineSelector` 按前缀 + 显式集合自动路由：

- `qemu:` 开头或不在任何引擎集合中 → QEMU
- `mac128k`、`mac512k`、`macplus`、`macse`… → Mini vMac
- `macii*`、`maclc*`、`macquadra*`、`maccentris*`、`macperforma*` → BasiliskII
- `ppc*`、`powermac*`、`g3*`、`g4*` → SheepShaver
- `dosbox*` → DOSBox
- `dosbox-x*` → DOSBox-X
- `pcem*` → PCem
- `86box*` → 86Box
- `c64*`、`c128*`、`pet*`、`vic20*` → VICE
- `amiga*` → FS-UAE
- `atarist*`、`atariste*`、`ataritt*`、`atarifalcon*` → Hatari
- `msx*` → OpenMSX
- `spectrum*`、`zx*` → Fuse
- `scumm*` → ScummVM
- `mednafen*` → Mednafen
- `aranym*` → ARAnyM

> 注：前缀规则放在 `VMStartEngineSelector` 的一张 NSDictionary 里，便于后续新增引擎时只改一处。

## 三、代码改造范围

### 3.1 协议与枚举
- `VMStartEngineProtocol.h`：`VMStartEngineType` 扩展为 16 个枚举值。
- 新增通用发现方法到 `VMStartEngineSelector`：
  - `+engineTypeForMachine:`
  - `+executablePathForEngineType:`
  - `+allEngineTypes`

### 3.2 新增 13 个引擎 wrapper
每个 wrapper 一个 `.h/.m` 文件，统一实现 `VMStartEngine` 协议：
- `VMStartSheepShaverProcess`
- `VMStartDOSBoxProcess`
- `VMStartDOSBoxXProcess`
- `VMStartPCemProcess`
- `VMStart86BoxProcess`
- `VMStartVICEProcess`
- `VMStartFSUAEProcess`
- `VMStartHatariProcess`
- `VMStartOpenMSXProcess`
- `VMStartFuseProcess`
- `VMStartScummVMProcess`
- `VMStartMednafenProcess`
- `VMStartARAnyMProcess`

每个 wrapper 至少实现：
- `initWithVirtualMachine:`
- `startWithError:`（构建命令行参数或配置文件）
- `stop` / `forceStop`
- 进程退出监控（NSTask 或 NSRunningApplication）

### 3.3 机型列表
- `VMStartArchitectureManager.m`：扩展 `m68k` 机器列表，并新增 `i386`、`powerpc`、`m68k-atari`、`z80`、`mos6502` 等架构条目，把对应机器类型合并进去。
- 例如：
  - `i386` 架构机器：PCem/86Box/DOSBox/DOSBox-X/QEMU 机型
  - `powerpc` 架构机器：SheepShaver 机型 + QEMU ppc 机型
  - `m68k-atari`：Hatari/ARAnyM 机型
  - `z80`：MSX/Spectrum 机型
  - `mos6502`：Commodore 机型

### 3.4 UI 自适应
重构 `VMStartConfigWindowController`：
- 把每个引擎的限制声明在一个 `EngineUILimits` 结构/字典里。
- 根据 `engineTypeForMachine:` 的结果一次性刷新所有控件。
- 为每个引擎配置：
  - CPU 核心数是否可变
  - 内存是否可变 / 固定值 / 最大值
  - 网络 / USB / HVF / 显示后端 / ISO / CD-ROM / BIOS / 共享文件夹 / ROM 文件 / 软盘 是否可用

### 3.5 工程配置
- `project.pbxproj`：添加 13×2 = 26 个新文件引用、Build Phase、Header Search Paths。

### 3.6 本地化
- 中文/英文 `Localizable.strings`：补充新架构名称、机型分组标签、引擎相关提示。

## 四、分阶段实施建议

**第一阶段（本次会话）**：完成协议/枚举/selector 重构 + 新增 13 个 wrapper 骨架 + 扩展机型列表 + project.pbxproj + 构建通过。
**第二阶段**：逐个完善每个 wrapper 的启动参数/配置文件生成逻辑。
**第三阶段**：UI 限制规则表 + 动态刷新 + 本地化 + DMG 打包。

## 五、风险与依赖

- 每个外部引擎都需要用户自行安装（版权/体积原因，不内置二进制）。
- 部分引擎 macOS 版本可能需要用户从 Homebrew 或官网下载。
- Mednafen/ScummVM 的"机器类型"概念较弱，需要设计虚拟机型（如 `mednafen-psx`、`scummvm-default`）。
- 所有新增代码文件必须加入 Xcode 工程，否则会出现之前的 `file not found` 错误。

## 六、文件变更清单

- `VMStart/Sources/Engine/VMStartEngineProtocol.h`
- `VMStart/Sources/Engine/VMStartEngineSelector.h/.m`
- `VMStart/Sources/Engine/VMStartQEMUProcess.h/.m`（可能需小改兼容）
- 新增 13 对 `.h/.m` wrapper 文件
- `VMStart/Sources/Models/VMStartArchitectureManager.m`
- `VMStart/Sources/UI/Controllers/VMStartConfigWindowController.m`
- `VMStart/Resources/zh-Hans.lproj/Localizable.strings`
- `VMStart/Resources/en.lproj/Localizable.strings`
- `VMStart.xcodeproj/project.pbxproj`