# v1.0.0

首个可用版本。

## Background

这个版本主要面向一个明确的实际需求：在 macOS 升级后，某些第三方蓝牙串口工具与系统兼容性变差，尤其是在网络设备调试场景中，连接过目标蓝牙设备后，往往还需要手动再次执行“忽略设备”，否则下次无法继续正常使用串口工具。

## Highlights

- 提供 macOS 原生 `.app` 形式的一键蓝牙断开 + 忽略工具
- 首次运行可手动选择要处理的蓝牙设备
- 支持“记住该设备”，后续双击直接执行
- 支持按住 `Option` 键强制重新选择设备
- 支持系统通知反馈执行结果
- 包含项目源码、图标资源和构建脚本，方便继续维护或上传 GitHub

## Included

- Swift 源码：`src/main.swift`
- 构建脚本：`build_app.sh`
- App 图标资源：`resources/AppIcon.icns`
- App 配置：`resources/Info.plist`

## Notes

- 运行前需要先安装 `blueutil`
- 如果系统没有授予蓝牙权限，需要在 macOS 设置中手动允许
