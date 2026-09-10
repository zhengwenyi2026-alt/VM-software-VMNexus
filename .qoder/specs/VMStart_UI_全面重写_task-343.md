# VMStart UI 全面重写方案

## 设计原则
- 参考 UTM 的简洁优雅 + VMware Workstation 的专业感
- 使用 SF Symbols 图标 + 圆角卡片 + 阴影
- 深色/浅色主题自适应
- 所有动画使用 NSAnimationContext 平滑过渡

---

## 1. Library 主窗口重写 (VMStartLibraryWindowController.m)

### 侧边栏
- 使用 NSOutlineView 替代 NSTableView，分组显示 "All VMs" / "Running" / "Favorites"
- 每个 VM 行：左侧彩色圆点 + VM 图标 (SF Symbol) + 名称 + 状态副标题
- 搜索框使用 NSSearchField 圆角样式
- 底部工具栏：图标按钮 (+ - Play Stop Settings)，使用 NSBezelStyleInline
- 添加分隔线和分组标题

### 主内容区
- **空状态**：居中显示大图标 (SF Symbol "externaldrive.connected.to.line.below") + 欢迎文字 + 大号 "Create New VM" 按钮
- **详情卡片**：圆角白色/深色卡片显示 VM 信息
  - 顶部：VM 名称 + 架构徽章
  - 状态指示器 (绿色/红色/黄色圆点 + 文字)
  - 配置摘要网格 (CPU / Memory / Disk / Network)
  - 操作按钮栏 (Start / Stop / Edit / Delete)

### 视觉改进
- 侧边栏宽度可调 (180-300pt)
- 选中行使用圆角高亮背景
- 添加 NSToolbar (可选)

---

## 2. Console 控制台窗口重写 (VMStartConsoleWindowController.m)

### 工具栏
- 使用 NSView 自定义深色背景 (rgb: 0.12, 0.12, 0.14)
- 按钮使用图标 (SF Symbol): play.fill / stop.fill / camera.fill / ellipsis.circle
- VM 名称显示在中央
- 状态指示灯 (闪烁绿点 = Running)

### VMStart 启动屏
- 全屏深色背景
- 居中显示 "VMStart" 大字 (48pt SF Pro Display Bold)
- 副标题 "Starting your virtual machine..."
- 旋转进度指示器 (NSProgressIndicator)
- 淡入淡出动画 (0.3s)

### 日志视图
- 等宽字体 (SF Mono 11pt)
- 深色背景 (rgb: 0.08, 0.08, 0.10)
- 绿色文字 (rgb: 0.2, 0.9, 0.4) 模拟终端效果
- 自动滚动到底部

---

## 3. Config Wizard 配置向导重写 (VMStartConfigWindowController.m)

### 整体布局 (VMware Workstation 风格)
- 左侧：垂直步骤列表，带数字圆圈 + 连接线
- 当前步骤高亮 (蓝色圆圈 + 蓝色文字)
- 已完成步骤显示勾号 (checkmark.circle.fill)
- 右侧：步骤内容区域，带卡片背景

### 步骤 1: Overview (概览)
- VM 名称输入框 (大号，圆角)
- 架构选择：图标网格 (每格 = 图标 + 名称 + 描述)
  - x86_64: "Intel/AMD PC"
  - ARM: "Apple Silicon / ARM"
  - Classic Mac: "Classic Macintosh"
  - 等等
- 机器类型下拉

### 步骤 2: Hardware (硬件)
- CPU 选择：下拉 + 核心数滑块 (带数值标签)
- 内存：数字输入 + 单位切换 + 滑块可视化
- 使用 NSSegmentedControl 或 NSSlider 增强视觉

### 步骤 3: Storage (存储)
- 磁盘大小：滑块 + 数字输入 + 单位
- 磁盘格式选项 (qcow2 / raw / vmdk)
- "使用现有磁盘" 开关 + 文件选择器

### 步骤 4: Boot Media (启动介质)
- ISO 文件选择：卡片式文件浏览器 (带图标预览)
- 支持的格式列表
- 拖拽区域 (NSTableView + drag/drop)

### 步骤 5: Network & Sharing (网络与共享)
- 网络模式：图标选择 (NAT / Bridge / None)
- 显示后端选择
- 复选框组 (Acceleration / Audio / USB)
- 共享文件夹表格

### 步骤 6: Summary (摘要)
- 配置卡片：两列布局显示所有设置
- 编辑链接 (点击跳转到对应步骤)
- 底部按钮：Cancel / Back / Finish

### 动画过渡
- 步骤切换使用 NSView 淡入淡出 + 滑动动画
- 按钮状态跟随步骤变化

---

## 4. 通用组件

### 自定义视图类
- `VMStartCardView`: 圆角卡片 (背景色 + 阴影 + 圆角)
- `VMStartIconButton`: 带图标的按钮 (hover 效果)
- `VMStartStatusBadge`: 状态徽章 (圆点 + 文字)

### 颜色系统
- 定义主题色 (Accent Color)
- 卡片背景色 (自动适配深色/浅色)
- 分隔线颜色
- 状态色 (绿/黄/红/灰)

---

## 5. 实施步骤

1. 创建通用组件类 (VMStartCardView, VMStartIconButton, VMStartStatusBadge)
2. 重写 Library 窗口 UI
3. 重写 Console 窗口 UI + 启动屏
4. 重写 Config Wizard 所有 6 个步骤
5. 构建验证 + 视觉调优

---

## 文件变更清单

| 文件 | 操作 |
|------|------|
| `VMStart/Sources/UI/Views/VMStartCardView.h/m` | 新增 |
| `VMStart/Sources/UI/Views/VMStartIconButton.h/m` | 新增 |
| `VMStart/Sources/UI/Views/VMStartStatusBadge.h/m` | 新增 |
| `VMStart/Sources/UI/Controllers/VMStartLibraryWindowController.m` | 重写 |
| `VMStart/Sources/UI/Controllers/VMStartConsoleWindowController.m` | 重写 |
| `VMStart/Sources/UI/Controllers/VMStartConfigWindowController.m` | 重写 |
| `VMStart/Resources/en.lproj/Localizable.strings` | 更新 |
| `VMStart/Resources/zh-Hans.lproj/Localizable.strings` | 更新 |
