# Bluetooth Ignore App

一个可双击运行的 macOS 蓝牙小工具。

核心能力：

- 首次运行时，用户可从已发现的蓝牙设备中选择一个目标设备。
- 选择时可勾选“记住该设备，下次直接执行”。
- 如果已记住设备，后续启动 app 会自动对该设备执行“断开 + 忽略（取消配对）”。
- 如果不勾选记住，则每次启动都会重新弹出设备选择框。

附加行为：

- 启动 app 时按住 `Option` 键，可强制重新选择设备。
- 操作结果优先通过系统通知返回；如果通知权限未开启，则会回退为原生提示框。

## 依赖

- macOS 12+
- `blueutil`

Homebrew 安装：

```bash
brew install blueutil
```

## 项目结构

```text
bluetooth-ignore-app/
├── build_app.sh
├── README.md
├── resources/
│   ├── AppIcon.icns
│   ├── icon-1024.png
│   └── Info.plist
├── src/
│   └── main.swift
└── dist/
    └── 蓝牙设备一键断开忽略.app
```

## 构建

在项目目录执行：

```bash
chmod +x ./build_app.sh
./build_app.sh
```

构建完成后，输出文件位于：

```text
./dist/蓝牙设备一键断开忽略.app
```

## 使用方式

1. 双击 `dist/蓝牙设备一键断开忽略.app`
2. 首次运行时选择目标蓝牙设备
3. 可选是否勾选“记住该设备，下次直接执行”

如果已经勾选记住：

- 以后直接双击 app，会自动对该设备执行断开 + 忽略

如果没有勾选记住：

- 以后每次双击 app，都会重新弹出设备选择

## 本地配置与日志

- 配置文件：`~/Library/Application Support/local.codex.bluetooth-ignore.selector/config.json`
- 运行日志：`~/Library/Application Support/local.codex.bluetooth-ignore.selector/run.log`

删除配置文件后，app 会重新回到首次选择流程。
