# KDE Plasma 6 macOS 风格 Dock 双方案指南

本项目现已全面支持 **两种截然不同设计侧重点** 的 macOS 风格 Dock 方案，并附带开箱即用的 **一键无缝热切换工具**。

---

## 方案总览与技术选型对比

| 维度 / 特性      | 方案 1：Quickshell 极致 macOS Dock（推荐）                   | 方案 2：KDE Plasma 6 原生浮动 Dock                               |
| :--------------- | :----------------------------------------------------------- | :--------------------------------------------------------------- |
| **底层引擎**     | Quickshell (Qt 6.9+ QML / Wayland Layer Shell)               | KDE Plasma 6 原生面板 (`plasmashell`)                            |
| **物理动效**     | **100% 还原 macOS 真实物理抛物线波浪鱼眼放大** (Cosine Wave) | 仅单图标线性微缩放或轻微浮动（无连续波浪扩散）                   |
| **高光与磨砂**   | 原生 macOS 1px 动态顶边缘高光 + 亚克力连续曲率圆角           | 跟随当前 Plasma 桌面主题（已完美适配 MacTahoe 磨砂浮动药丸底座） |
| **点击反馈**     | **macOS 经典弹性连续跳跃 (Double Bounce)**                   | 原生图标微闪烁                                                   |
| **面板尺寸形态** | 居中自适应浮动，药丸型微距脱离屏幕底边                       | **居中自适应浮动（Fit Content）**，双屏自适应，留白固定分隔      |
| **布局结构**     | `[应用图标区] ｜ [废纸篓] ⚙️`                                | `[应用图标区] ｜ [废纸篓]`                                       |
| **多屏幕定制**   | **支持全独立配置**（DP-1 与 eDP-1 可独立尺寸/动效/开关）     | **双屏均自动生成专属独立 macOS 居中浮动 Dock**                   |
| **神灯特效支持** | 原生配合 KWin `magic-lamp` 窗口最小化神灯特效                | 原生配合 KWin `magic-lamp` 窗口最小化神灯特效                    |
| **内存额外开销** | 约 **260MB ~ 290MB**（独立 Qt6/Wayland 渲染器守护进程）      | **~40MB 内存增量**（0 独立进程，融入 plasmashell 共享池）        |
| **CPU 空闲占用** | **0.0%**（无鼠标悬浮或活动时完全停止重绘）                   | **0.0%**                                                         |
| **适合用户群**   | **对 macOS 动效质感、物理波浪放大、视觉细节有极致要求者**    | **极致追求极简轻量、超低内存开销、原生一体化者**                 |

---

## 一键切换工具：`dock-switch.sh`

项目在 `scripts/dock-switch.sh` 提供了自动化管理工具，支持一键切换、互斥防冲突、状态查询与开机自启管理：

### 1. 切换至【方案 1：Quickshell 极致 Dock】

```bash
cd /home/hu-hub/Github/kde-quickshell-dock
./scripts/dock-switch.sh 1
# 或
./scripts/dock-switch.sh quickshell
```

- 自动清理屏幕底部的原生面板（防重叠）。
- 启动/重载 Quickshell 守护进程，即刻获得原汁原味的 macOS 视觉与物理交互。

### 2. 切换至【方案 2：KDE 原生浮动 Dock】

```bash
cd /home/hu-hub/Github/kde-quickshell-dock
./scripts/dock-switch.sh 2
# 或
./scripts/dock-switch.sh native
```

- 自动平稳停止 Quickshell 独立进程。
- 自动调用 Plasma 6 Scripting API 在所有可用屏幕底边生成**居中、自适应宽度（Fit Content）、圆角悬浮（Floating）、半透明磨砂**的 macOS 布局原生面板（包含：IconTasks 常用应用固定 + 间隔分隔 + 废纸篓）。

### 3. 查看当前哪套方案正在运行

```bash
./scripts/dock-switch.sh status
```

### 4. 设置开机自启

```bash
# 设为开机默认启动方案 1 (Quickshell)
./scripts/dock-switch.sh autostart quickshell

# 取消方案 1 自启，默认使用方案 2 (KDE 原生面板由 plasmashell 自身持久化记忆)
./scripts/dock-switch.sh autostart native
```

---

## 方案 2 (KDE 原生面板) 如何深度自定义样式？

方案 2 已经通过脚本深度定制成了高仿 macOS 的浮动形态：

1. **自动居中自适应紧凑尺寸（Fit Content）**：不会像传统任务栏那样横跨整屏，而是像 macOS Dock 一样随应用图标数量自适应伸缩紧凑收纳。
2. **边缘圆角浮动微距（Floating Panel）**：底部悬浮脱离底边，配合 MacTahoe 主题呈现高质感半透明玻璃圆角药丸底座。
3. **经典 macOS 结构布局**：内置常用应用固定（文件管理器、Edge、IDE、终端、系统设置等）+ 分隔微距 + 右侧独立废纸篓（Trash Can）。
4. **支持 GUI 可视化微调**：
   - 在原生底栏任意空白位置右键 -> 选择 **「进入编辑模式」**；
   - 可以自由拖拽滑块调整面板高度（默认 58px）；
   - 可以切换显示模式（「常驻」或「避让窗口 Dodge Windows」）；
   - 可以直接将开始菜单里的任何软件拖拽放到底栏固定，或右键取消固定。
