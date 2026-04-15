# 蓝牙设备一键断开忽略

[![macOS](https://img.shields.io/badge/macOS-12%2B-111111?logo=apple&logoColor=white)](https://support.apple.com/macos)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-F05138?logo=swift&logoColor=white)](https://www.swift.org/)
[![License](https://img.shields.io/github/license/useraby/bluetooth-ignore-app)](./LICENSE)
[![Tag](https://img.shields.io/github/v/tag/useraby/bluetooth-ignore-app?label=version)](https://github.com/useraby/bluetooth-ignore-app/tags)
[![Last Commit](https://img.shields.io/github/last-commit/useraby/bluetooth-ignore-app)](https://github.com/useraby/bluetooth-ignore-app/commits/main)

一个面向 macOS 的轻量蓝牙小工具：选择目标蓝牙设备后，可一键执行“断开 + 忽略（取消配对）”；也支持记住设备，之后双击直接执行。

## 项目背景

这个工具来自一个很具体的日常场景：在 macOS 升级后，某些第三方蓝牙串口工具与系统兼容性变差。对于华为交换机设备调试这类网络工程工作流，使用串口工具连接过目标蓝牙设备后，往往还需要手动再次“忽略”该设备，否则下次无法正常继续使用该串口工具。

这个 app 的目标不是管理所有蓝牙设备，而是把这类“断开 + 忽略”的重复操作压缩成一次双击，减少每次调试前后的手工处理成本。

## 功能特性

- 首次运行时，弹出极简设备选择框，用户可从当前蓝牙设备列表中选择目标设备。
- 可勾选“记住该设备，下次直接执行”。
- 如果已记住设备，后续启动 app 会自动对该设备执行断开 + 忽略。
- 如果未勾选记住，则每次启动都会重新弹出选择框。
- 启动时按住 `Option` 键，可强制重新选择设备。
- 操作结果优先通过系统通知返回；如果通知权限不可用，则回退为原生提示框。

## 使用场景

- 华为交换机等网络设备调试场景
- macOS 升级后，第三方蓝牙串口工具与系统兼容性下降
- 每次串口调试结束后，都需要再次忽略同一个蓝牙设备
- 经常需要断开某个蓝牙串口设备
- 需要快速忽略某个已配对蓝牙设备
- 想把常用处理动作做成可双击运行的小工具

## 依赖

- macOS 12+
- [`blueutil`](https://github.com/toy/blueutil)

通过 Homebrew 安装：

```bash
brew install blueutil
```

## 快速开始

1. 克隆仓库
2. 安装 `blueutil`
3. 构建 app
4. 双击运行生成的 `.app`

```bash
git clone https://github.com/useraby/bluetooth-ignore-app.git
cd bluetooth-ignore-app
chmod +x ./build_app.sh
./build_app.sh
open "./dist/蓝牙设备一键断开忽略.app"
```

构建完成后，输出文件位于：

```text
./dist/蓝牙设备一键断开忽略.app
```

## 使用说明

首次运行：

1. 双击 `dist/蓝牙设备一键断开忽略.app`
2. 从下拉框中选择目标蓝牙设备
3. 视情况决定是否勾选“记住该设备，下次直接执行”
4. 点击“执行”

后续运行：

- 如果已经记住设备：双击 app 后直接执行
- 如果没有记住设备：每次都会重新弹出选择框
- 如果想忽略已记住配置并重新选设备：启动时按住 `Option` 键

## 本地配置与日志

- 配置文件：`~/Library/Application Support/local.codex.bluetooth-ignore.selector/config.json`
- 运行日志：`~/Library/Application Support/local.codex.bluetooth-ignore.selector/run.log`

删除配置文件后，app 会回到首次选择流程。

## 项目结构

```text
bluetooth-ignore-app/
├── build_app.sh
├── LICENSE
├── README.md
├── RELEASE_NOTES_v1.0.0.md
├── resources/
│   ├── AppIcon.icns
│   ├── icon-1024.png
│   └── Info.plist
├── src/
│   └── main.swift
└── dist/
    └── 蓝牙设备一键断开忽略.app
```

## 构建说明

项目当前使用一个简单的 shell 构建脚本：

```bash
./build_app.sh
```

该脚本会：

- 编译 `src/main.swift`
- 生成 `.app` bundle
- 拷贝图标和 `Info.plist`
- 对生成产物做本地 ad-hoc 签名

## 发布

- 首个版本标签：`v1.0.0`
- 发布说明文件：[`RELEASE_NOTES_v1.0.0.md`](./RELEASE_NOTES_v1.0.0.md)

## License

本项目使用 [MIT License](./LICENSE)。
