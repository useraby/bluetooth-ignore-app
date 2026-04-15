import AppKit
import Foundation
import UserNotifications

let appName = "蓝牙设备一键断开忽略"
let bundleIdentifier = Bundle.main.bundleIdentifier ?? "local.codex.bluetooth-ignore.selector"
let environment = ProcessInfo.processInfo.environment
let statusUI = environment["STATUS_UI"] != "0"

struct BluetoothDevice: Codable, Hashable {
    let name: String
    let address: String
    let connected: Bool
}

struct RememberedDeviceConfig: Codable {
    let deviceName: String
    let deviceAddress: String
}

struct CommandResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32
}

struct DeviceSelectionResult {
    let device: BluetoothDevice
    let rememberDevice: Bool
}

enum AppError: LocalizedError {
    case blueutilMissing
    case noBluetoothDevices
    case userCancelled
    case invalidBluetoothInventory
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .blueutilMissing:
            return "未找到 blueutil，请先安装 blueutil 后再运行。"
        case .noBluetoothDevices:
            return "没有找到可选择的蓝牙设备，请先确认设备已配对。"
        case .userCancelled:
            return "已取消本次操作。"
        case .invalidBluetoothInventory:
            return "无法读取蓝牙设备列表。"
        case .operationFailed(let message):
            return message
        }
    }
}

final class AppLogger {
    private let fileURL: URL
    private let dateFormatter: DateFormatter

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let directory = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
    }

    func log(_ message: String) {
        let line = "[\(dateFormatter.string(from: Date()))] \(message)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }
}

let fileManager = FileManager.default
let appSupportDirectory: URL = {
    if let override = environment["CONFIG_DIR_OVERRIDE"], !override.isEmpty {
        let dir = URL(fileURLWithPath: override, isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let dir = base.appendingPathComponent(bundleIdentifier, isDirectory: true)
    try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
}()
let configURL = appSupportDirectory.appendingPathComponent("config.json")
let logURL = appSupportDirectory.appendingPathComponent("run.log")
let logger = AppLogger(fileURL: logURL)

func currentModifierFlags() -> NSEvent.ModifierFlags {
    NSEvent.modifierFlags
}

func currentNotificationAuthorizationStatus() -> UNAuthorizationStatus {
    let center = UNUserNotificationCenter.current()
    let semaphore = DispatchSemaphore(value: 0)
    var status: UNAuthorizationStatus = .notDetermined

    center.getNotificationSettings { settings in
        status = settings.authorizationStatus
        semaphore.signal()
    }

    while semaphore.wait(timeout: .now() + 0.1) == .timedOut {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
    }

    return status
}

func requestNotificationAuthorizationIfNeeded() -> Bool {
    let center = UNUserNotificationCenter.current()
    let status = currentNotificationAuthorizationStatus()

    switch status {
    case .authorized, .provisional, .ephemeral:
        return true
    case .denied:
        return false
    case .notDetermined:
        let semaphore = DispatchSemaphore(value: 0)
        var granted = false

        center.requestAuthorization(options: [.alert, .sound, .badge]) { allowed, _ in
            granted = allowed
            semaphore.signal()
        }

        while semaphore.wait(timeout: .now() + 0.1) == .timedOut {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
        }

        return granted
    @unknown default:
        return false
    }
}

func openURL(_ urlString: String) {
    guard let url = URL(string: urlString) else {
        return
    }
    NSWorkspace.shared.open(url)
}

func openNotificationSettingsIfNeeded() {
    let candidates = [
        "x-apple.systempreferences:com.apple.Notifications-Settings.extension?\(bundleIdentifier)",
        "x-apple.systempreferences:com.apple.preference.notifications"
    ]
    for candidate in candidates {
        if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
            return
        }
    }
}

func openBluetoothPrivacySettings() {
    let candidates = [
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Bluetooth",
        "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
    ]
    for candidate in candidates {
        if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
            return
        }
    }
}

func showAlert(title: String, message: String, style: NSAlert.Style) {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    NSApp.activate(ignoringOtherApps: true)

    let alert = NSAlert()
    alert.alertStyle = style
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "好")
    alert.runModal()
}

@discardableResult
func postNotification(title: String, message: String) -> Bool {
    guard requestNotificationAuthorizationIfNeeded() else {
        return false
    }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = message
    content.sound = .default

    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
    )

    let center = UNUserNotificationCenter.current()
    let semaphore = DispatchSemaphore(value: 0)
    var success = true
    center.add(request) { error in
        if error != nil {
            success = false
        }
        semaphore.signal()
    }

    while semaphore.wait(timeout: .now() + 0.1) == .timedOut {
        RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
    }

    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))
    return success
}

func showSuccess(_ message: String) {
    logger.log("Success: \(message)")
    if statusUI {
        if !postNotification(title: "执行成功", message: message) {
            showAlert(title: "执行成功", message: message, style: .informational)
        }
    } else {
        print("执行成功：\(message)")
    }
}

func showFailure(_ message: String) -> Never {
    logger.log("Failure: \(message)")
    if statusUI {
        if currentNotificationAuthorizationStatus() == .denied {
            openNotificationSettingsIfNeeded()
        }
        if !postNotification(title: "执行失败", message: message) {
            showAlert(title: "执行失败", message: message, style: .critical)
        }
    } else {
        fputs("执行失败：\(message)\n", stderr)
    }
    exit(1)
}

func loadRememberedConfig() -> RememberedDeviceConfig? {
    guard let data = try? Data(contentsOf: configURL) else {
        return nil
    }
    return try? JSONDecoder().decode(RememberedDeviceConfig.self, from: data)
}

func saveRememberedConfig(for device: BluetoothDevice) throws {
    let config = RememberedDeviceConfig(deviceName: device.name, deviceAddress: device.address)
    let data = try JSONEncoder().encode(config)
    try data.write(to: configURL, options: .atomic)
    logger.log("Saved remembered device: \(device.name) (\(device.address))")
}

func clearRememberedConfig() {
    try? fileManager.removeItem(at: configURL)
    logger.log("Cleared remembered device config")
}

func resolveBlueutilPath() -> String? {
    let candidates = [
        ProcessInfo.processInfo.environment["BLUEUTIL_BIN"],
        "/opt/homebrew/bin/blueutil",
        "/usr/local/bin/blueutil"
    ].compactMap { $0 }

    for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
        return candidate
    }

    if let result = try? runCommand(
        executablePath: "/usr/bin/which",
        arguments: ["blueutil"]
    ), result.exitCode == 0 {
        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty, fileManager.isExecutableFile(atPath: path) {
            return path
        }
    }

    return nil
}

func runCommand(
    executablePath: String,
    arguments: [String],
    environment: [String: String] = ProcessInfo.processInfo.environment
) throws -> CommandResult {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executablePath)
    process.arguments = arguments
    process.environment = environment

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

    return CommandResult(
        stdout: String(data: stdoutData, encoding: .utf8) ?? "",
        stderr: String(data: stderrData, encoding: .utf8) ?? "",
        exitCode: process.terminationStatus
    )
}

func parseDevices(from jsonData: Data) throws -> [BluetoothDevice] {
    guard
        let root = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
        let inventory = (root["SPBluetoothDataType"] as? [[String: Any]])?.first
    else {
        throw AppError.invalidBluetoothInventory
    }

    var byAddress: [String: BluetoothDevice] = [:]

    func absorb(listKey: String, connected: Bool) {
        let entries = inventory[listKey] as? [[String: Any]] ?? []
        for entry in entries {
            for (deviceName, rawValue) in entry {
                guard
                    let rawDevice = rawValue as? [String: Any],
                    let address = rawDevice["device_address"] as? String
                else {
                    continue
                }

                byAddress[address] = BluetoothDevice(
                    name: deviceName,
                    address: address,
                    connected: connected
                )
            }
        }
    }

    absorb(listKey: "device_connected", connected: true)
    absorb(listKey: "device_not_connected", connected: false)

    return byAddress.values.sorted {
        if $0.connected != $1.connected {
            return $0.connected && !$1.connected
        }
        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
}

func fetchBluetoothDevices() throws -> [BluetoothDevice] {
    let result = try runCommand(
        executablePath: "/usr/sbin/system_profiler",
        arguments: ["SPBluetoothDataType", "-json"]
    )

    guard result.exitCode == 0, let data = result.stdout.data(using: .utf8) else {
        throw AppError.invalidBluetoothInventory
    }

    let devices = try parseDevices(from: data)
    guard !devices.isEmpty else {
        throw AppError.noBluetoothDevices
    }

    logger.log("Loaded \(devices.count) Bluetooth devices from system_profiler")
    return devices
}

func displayName(for device: BluetoothDevice) -> String {
    let state = device.connected ? "已连接" : "未连接"
    let addressSuffix = String(device.address.suffix(8))
    return "\(device.name) (\(addressSuffix), \(state))"
}

func promptForDeviceSelection(
    devices: [BluetoothDevice],
    preferredAddress: String?,
    defaultRememberState: Bool,
    forceSelection: Bool
) throws -> DeviceSelectionResult {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    NSApp.activate(ignoringOtherApps: true)

    let alert = NSAlert()
    alert.icon = nil
    alert.messageText = forceSelection ? "重新选择蓝牙设备" : "选择蓝牙设备"
    alert.informativeText = ""
    alert.alertStyle = .informational
    alert.addButton(withTitle: "执行")
    alert.addButton(withTitle: "取消")

    let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 50))
    let popupButton = NSPopUpButton(frame: NSRect(x: 0, y: 24, width: 340, height: 26), pullsDown: false)
    devices.forEach { popupButton.addItem(withTitle: displayName(for: $0)) }
    if let preferredAddress, let index = devices.firstIndex(where: { $0.address == preferredAddress }) {
        popupButton.selectItem(at: index)
    }
    accessory.addSubview(popupButton)

    let rememberCheckbox = NSButton(checkboxWithTitle: "记住该设备，下次直接执行", target: nil, action: nil)
    rememberCheckbox.frame = NSRect(x: 0, y: 0, width: 240, height: 18)
    rememberCheckbox.state = defaultRememberState ? .on : .off
    accessory.addSubview(rememberCheckbox)

    alert.accessoryView = accessory

    let response = alert.runModal()
    guard response == .alertFirstButtonReturn else {
        throw AppError.userCancelled
    }

    return DeviceSelectionResult(
        device: devices[popupButton.indexOfSelectedItem],
        rememberDevice: rememberCheckbox.state == .on
    )
}

func bestEffortMessage(from stdout: String, stderr: String) -> String {
    let combined = [stderr, stdout]
        .joined(separator: "\n")
        .split(whereSeparator: \.isNewline)
        .map(String.init)
        .reversed()

    return combined.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) ?? "未知错误"
}

func performDisconnectAndIgnore(for device: BluetoothDevice) throws -> String {
    guard let blueutilPath = resolveBlueutilPath() else {
        throw AppError.blueutilMissing
    }

    logger.log("Starting device operation for \(device.name) (\(device.address))")

    let disconnectResult = try runCommand(
        executablePath: blueutilPath,
        arguments: ["--disconnect", device.address]
    )
    logger.log("Disconnect exit code: \(disconnectResult.exitCode)")

    let waitResult = try runCommand(
        executablePath: blueutilPath,
        arguments: ["--wait-disconnect", device.address, "8"]
    )
    logger.log("Wait-disconnect exit code: \(waitResult.exitCode)")

    let unpairResult = try runCommand(
        executablePath: blueutilPath,
        arguments: ["--unpair", device.address]
    )
    logger.log("Unpair exit code: \(unpairResult.exitCode)")

    if disconnectResult.exitCode == 134 || waitResult.exitCode == 134 || unpairResult.exitCode == 134 {
        openBluetoothPrivacySettings()
        throw AppError.operationFailed(
            "缺少蓝牙权限，请在“系统设置 -> 隐私与安全性 -> 蓝牙”中允许 \(appName) 后重试。"
        )
    }

    if unpairResult.exitCode != 0 {
        let reason = bestEffortMessage(from: unpairResult.stdout, stderr: unpairResult.stderr)
        throw AppError.operationFailed("已尝试断开，但忽略失败：\(reason)")
    }

    let disconnectNote: String
    if disconnectResult.exitCode == 0 {
        disconnectNote = device.connected ? "已断开并忽略" : "已忽略"
    } else {
        disconnectNote = "已忽略"
    }

    return "\(disconnectNote)：\(device.name)"
}

func rememberedDeviceIfAvailable(forceSelection: Bool) -> RememberedDeviceConfig? {
    guard !forceSelection else {
        logger.log("Option key detected, forcing device selection")
        return nil
    }
    return loadRememberedConfig()
}

func main() {
    logger.log("App launch")

    let forceSelection = currentModifierFlags().contains(.option)

    do {
        let devices = try fetchBluetoothDevices()
        let rememberedConfig = rememberedDeviceIfAvailable(forceSelection: forceSelection)

        let selection: DeviceSelectionResult
        if let rememberedConfig {
            let rememberedDevice = devices.first {
                $0.address.caseInsensitiveCompare(rememberedConfig.deviceAddress) == .orderedSame
            } ?? BluetoothDevice(
                name: rememberedConfig.deviceName,
                address: rememberedConfig.deviceAddress,
                connected: false
            )

            selection = DeviceSelectionResult(device: rememberedDevice, rememberDevice: true)
            logger.log("Using remembered device: \(rememberedDevice.name) (\(rememberedDevice.address))")
        } else {
            selection = try promptForDeviceSelection(
                devices: devices,
                preferredAddress: loadRememberedConfig()?.deviceAddress,
                defaultRememberState: false,
                forceSelection: forceSelection
            )
            logger.log("User selected device: \(selection.device.name) (\(selection.device.address)); remember=\(selection.rememberDevice)")
        }

        if selection.rememberDevice {
            try saveRememberedConfig(for: selection.device)
        } else {
            clearRememberedConfig()
        }

        let resultMessage = try performDisconnectAndIgnore(for: selection.device)
        showSuccess(resultMessage)
        exit(0)
    } catch AppError.userCancelled {
        logger.log("User cancelled selection")
        exit(0)
    } catch let error as AppError {
        showFailure(error.errorDescription ?? "执行失败")
    } catch {
        showFailure(error.localizedDescription)
    }
}

main()
