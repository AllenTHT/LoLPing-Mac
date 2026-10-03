# LoLPing · Mac 桌面信号

一个原生 Swift / AppKit 菜单栏软件。在 Mac 上按住组合键，移动鼠标选择英雄联盟风格的信号，松开发送。

## 下载与安装

**[下载 LoLPing v1.1.0 · Apple Silicon（ZIP）](https://github.com/AllenTHT/LoLPing-Mac/releases/download/v1.1.0/LoLPing-v1.1.0-macOS-arm64.zip)** · [查看最新版本](https://github.com/AllenTHT/LoLPing-Mac/releases/latest)

- 适用设备：Apple Silicon（M 系列芯片）Mac；当前安装包不支持 Intel Mac。
- 系统要求：macOS 13 或更新版本。目前仅在 macOS 15.7.3 实测，其他系统版本和外接屏尚未实测。
- 下载包内包含 App、图标及音效；使用时无需安装 Xcode、Swift 或其他开发工具。

1. 点击上方下载链接，或在 Releases 页面的 **Assets** 中下载 `LoLPing-v1.1.0-macOS-arm64.zip`。GitHub 自动提供的 `Source code (zip)` 和 `Source code (tar.gz)` 是源码，不是 App 安装包。
2. 双击 ZIP 解压，将 `LoLPing.app` 拖入「应用程序」文件夹。
3. 从「应用程序」打开 LoLPing。当前版本使用本地签名，尚未使用 Developer ID 签名及 Apple 公证。如果系统提示无法验证开发者，确认下载来源可信且 App 未被篡改后，在尝试打开后进入 **系统设置 → 隐私与安全性 → 仍要打开**，并确认打开。详见 [Apple 官方说明](https://support.apple.com/zh-cn/102445)。
4. 开启「启用 Ping」，按照提示进入 **系统设置 → 隐私与安全性 → 辅助功能**，允许 **LoLPing**；如果应用提示需要重新打开，请退出后重新运行，再开启开关。
5. 按照下方「使用」说明发送信号。首次安装默认关闭，需要手动开启。

## 使用

1. 打开 LoLPing，在「信号试用」中点选九种信号。窗口内预览不需要系统权限，也不受全局开关限制。
2. 开启「启用 Ping」。如果提示授权，进入 **系统设置 → 隐私与安全性 → 辅助功能**，允许 **LoLPing**。这一步需要你亲自操作；应用不会替你更改系统权限。
3. 将鼠标放在要标记的位置，按住 **Control + Option + Command** 约 0.18 秒，移动鼠标选择，松开任意一键发送。无需按住鼠标按钮。
4. 中央是普通蓝色信号；Esc / 右键取消。信号出现在最初呼出的位置。下一次操作前，请完全松开三个修饰键。
5. 关闭总开关会立刻取消轮盘、停止动画与声音。关闭窗口仍可从菜单栏打开或暂停；「退出软件」彻底退出。

首次运行默认关闭。启用状态、组合键、音量和大小自动保存。软件不会添加登录启动项，不联网同步信号，也不采集键盘输入内容。

菜单栏和主窗口共用一个状态。为避免快捷键冲突，在轮盘打开前后按下其他普通按键或额外修饰键，都会取消当前手势并放行原快捷键。

如果辅助功能已开启但无法触发，请关闭并重新运行应用，再检查权限帮助。只有系统确实要求时才额外开启输入监控；不需要屏幕录制或麦克风权限。重新构建会改变本地签名，macOS 可能要求重新添加授权条目。

## 素材与效果

- 官方布局与视觉参照：<https://support.riotgames.com/en-us/league-of-legends/gameplay/smart-ping>
- 图标依据：CommunityDragon 15.24 的 `assets/ux/menu/` 轮盘图集。它是社区维护的游戏素材镜像，不是 Riot 官方服务。按轮盘图标轮廓重建可缩放矢量路径，修整压缩纹理的边缘噪点；不再放大小地图图片。
- 轮盘悬浮时图标从 22 点平滑放大到 30 点，并改变颜色与扇区高亮。中心圆半径为 66 点，实际判定区域同步缩放；金色尖角、青色短弧随指针方向旋转，功能名称显示在中心。
- 音效来源：`alibaztomars/lol-ping-overlay` 的九个音频文件，锁定具体提交；详见 `Resources/asset-sources.json`。与 Riot 原录音完全一致尚未核实，不标称官方原声。
- 游戏素材归 Riot Games 所有。LoLPing 是独立的个人桌面工具，非 Riot 官方产品。
- 动画使用原生 AppKit / Quartz 绘制，包含独立变化的浮起、辉光、扩散光圈、短暂光点和约两秒淡出。蓝色普通 Ping 对照用户提供的实拍视频调整；其余八种落点动画是同风格重建，未经逐帧原版对照。
- 图标、文字和光圈按屏幕像素倍率绘制，支持 Retina。效果预览高度随大小调整，最大 150% 时也能容纳完整图标。

## 构建与检查

需要 macOS 13 或更新版本及 Swift 命令行工具。当前交付针对 Apple Silicon；无需额外第三方运行库或完整 Xcode。

```sh
zsh scripts/build.sh
zsh scripts/test.sh
dist/LoLPing.app/Contents/MacOS/LoLPing --check-assets
dist/LoLPing.app/Contents/MacOS/LoLPing --visual-check "$PWD/Verification/Visuals"
```

构建脚本生成并本地签名 `dist/LoLPing.app`。首次取得素材或恢复缺失素材时可运行 `python3 scripts/fetch_assets.py`，正常构建与软件运行均无需网络。

`--visual-check` 使用与应用相同的绘制和动画插值，输出九种状态的 75% / 100% / 150% Retina 对照图、1x 图、动画阶段图及无声演示视频。它检查九种效果的动态变化和立即停止行为，不创建全局输入监听、不改偏好设置、不捕获桌面。生成视频需要系统编码器，受限沙箱可能无法调用。

轮廓数据随软件离线打包；仅维护素材时才需要 `scripts/trace_wheel_icons.py`（Pillow + NumPy），普通构建与使用不依赖 Python。

全局手势状态机有单元测试，包括所有释放顺序、重复触发、取消、其他快捷键、现有拖动、八向和屏幕边缘坐标。实际辅助功能授权、外接屏及不同应用的全屏覆盖仍需实机检查；系统受保护画面不保证覆盖。

测试使用独立的 `PingCoreChecks` 程序，因为仅安装 Command Line Tools 的 Mac 不一定带 XCTest；失败时返回非零退出状态。
