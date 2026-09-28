# KDE Plasma 6 macOS 风格 Dock 双方案指南

本项目现已全面支持 **两种截然不同设计侧重点** 的 macOS 风格 Dock 方案，并附带开箱即用的 **一键无缝热切换工具**。

---

## 方案总览与技术选型对比

| 维度 / 特性 | 方案 1：Quickshell 极致 macOS Dock（推荐） | 方案 2：KDE Plasma 6 原生浮动 Dock |
| :--- | :--- | :--- |
| **底层引擎** | Quickshell (Qt 6.9+ QML / Wayland Layer Shell) | KDE Plasma 6 原生面板 (`plasmashell`) |
| **物理动效** | **100% 还原 macOS 真实物理抛物线波浪鱼眼放大** (Cosine Wave) | 仅单图标线性微缩放或轻微浮动（无连续波浪扩散） |
| **高光与磨砂** | 原生 macOS 1px 动态顶边缘高光 + 亚克力连续曲率圆角 | 跟随当前 Plasma 桌面主题的半透明磨砂 |
| **点击反馈** | **macOS 经典弹性连续跳跃 (Double Bounce)** | 原生图标微闪烁 |
| **多屏幕定制** | **支持全独立配置**（DP-1 与 eDP-1 可独立尺寸/动效/开关） | Plasma 原生多屏克隆需手动编辑配置 |
| **神灯特效支持**| 原生配合 KWin `magic-lamp` 窗口最小化神灯特效 | 原生配合 KWin `magic-lamp` 窗口最小化神灯特效 |
| **内存额外开销**| 约 **260MB ~ 310MB**（独立 Qt6/Wayland 渲染器守护进程） | **~40MB 内存增量**（0 独立进程，融入 plasmashell 共享池） |
| **CPU 空闲占用**| **0.0%**（无鼠标悬浮或活动时完全停止重绘） | **0.0%** |
| **适合用户群** | **对 macOS 动效质感、物理波浪放大、视觉细节有极致要求者** | **极致追求极简轻量、超低内存开销、原生一体化者** |

---

## 一键切换工具：`dock-switch.sh`

项目在 `scripts/dock-switch.sh` 提供了自动化管理工具，支持一键切换、互斥防冲突、状态查询与开机自启管理：

### 1. 切换至【方案 1：Quickshell 极致 Dock】
```bash
./scripts/dock-switch.sh 1
# 或
./scripts/dock-switch.sh quickshell
```
- 会自动移除底部冲突的原生面板。
- 启动/重载 Quickshell 守护进程，即刻获得原汁原味的 macOS 视觉与物理交互。

### 2. 切换至【方案 2：KDE 原生浮动 Dock】
```bash
./scripts/dock-switch.sh 2
# 或
./scripts/dock-switch.sh native
```
- 会自动平稳停止 Quickshell 独立进程。
- 自动调用 Plasma 6 Scripting API 在屏幕底边生成居中、自适应宽度、浮动避让的 macOS 布局原生面板（包含：IconTasks 仅图标任务栏 + 边距分隔符 + 垃圾桶）。

### 3. 查看当前哪套方案正在运行
```bash
./scripts/dock-switch.sh status
```
输出示例：
```text
======================================================
       KDE Plasma macOS Dock 方案运行状态检查        
======================================================
 [●] 方案 1 (Quickshell 极致 macOS Dock): 正在运行 (PID: 155192, 物理内存: ~277MB)
 [ ] 方案 2 (KDE 原生浮动 Dock 面板): 未激活
------------------------------------------------------
 开机自启状态: 已配置 Quickshell Dock 开机自启
======================================================
```

### 4. 设置开机自启
```bash
# 设为开机默认启动方案 1 (Quickshell)
./scripts/dock-switch.sh autostart quickshell

# 取消方案 1 自启，默认使用方案 2 (KDE 原生面板由 plasmashell 自身持久化记忆)
./scripts/dock-switch.sh autostart native
```

---

## 方案 1 (Quickshell) 核心特性亮点
1. **真实余弦连续波浪放大算法**：光标滑过 Dock 时，邻近图标随高斯/余弦曲率连续隆起放大，与 macOS 行为分毫不差。
2. **多屏幕独立参数定制面板**：
   - 外部大屏（如 DP-1）可设置 56px 舒适大图标、1.8x 波浪放大；
   - 笔记本内屏（如 eDP-1）可独立设置 40px 紧凑图标，甚至独立关闭内屏 Dock；
   - 支持多屏一键配置复制与重置。
3. **macOS 启动跳跃与指示器**：
   - 应用点击时呈二次弹跳（Double Bounce）物理阻尼动效。
   - 底部采用真实 macOS 药丸型柔和光晕运行圆点指示器。
4. **Wayland 边缘自适应**：
   - 彻底修复了底部浮动状态下右侧齿轮截断问题。

---

## 方案 2 (KDE 原生面板) 核心特性亮点
1. **0 额外守护进程**：完全依托于系统现有的 `plasmashell` 进程，不增加额外架构依赖。
2. **极简超低开销**：仅新增组件实例，内存占用仅增加约 40MB，极其适合核显笔记本或资源敏感型场景。
3. **原生窗口自动避让**：原生享受 Plasma 6 的 `windowdodge` (窗口遮挡自动避让) 与 Wayland 合成器深度结合。
4. **右键管理**：右键面板任意空白区域即可进入 KDE 编辑模式调整高度或位置。
