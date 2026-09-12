import AppKit
import DropAgentAgent
import SwiftUI

extension AppDelegate {
    func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.autosaveName = "DropAgentStatusItem"
        item.behavior = []
        item.isVisible = true
        if let button = item.button {
            button.image = StatusIcon.image()
            button.imagePosition = .imageOnly
            button.title = ""
            button.toolTip = "DropAgent"
            button.setAccessibilityLabel("DropAgent")
            button.target = self
            button.action = #selector(statusClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            let drop = StatusDropView(frame: button.bounds)
            drop.autoresizingMask = [.width, .height]
            drop.session = session
            drop.panelVisible = { [weak self] in self?.panel?.isVisible == true }
            drop.onClick = { [weak self] in self?.statusClicked(nil) }
            drop.onDropAdmitted = { [weak self] in self?.showPanel() }
            button.addSubview(drop)
            button.registerForDraggedTypes(IncomingDrop.draggedTypes)
        }
        statusItem = item
        pinStatusItem()
    }

    func pinStatusItem() {
        guard let item = statusItem else { return }
        item.behavior = []
        item.isVisible = true
    }

    @objc func statusClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
            return
        }
        togglePanel()
    }

    func showMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(
            withTitle: session.hasAgent
                ? Copy.t("\(session.tuiTitle) 已连接", "\(session.tuiTitle) connected")
                : Copy.t("未发现终端 Agent", "No terminal agent found"),
            action: nil,
            keyEquivalent: ""
        )
        let tuiMenu = NSMenu(title: Copy.t("终端", "Terminal"))
        let autoItem = tuiMenu.addItem(withTitle: Copy.t("自动", "Auto"), action: #selector(selectTUIAuto), keyEquivalent: "")
        autoItem.target = self
        autoItem.state = session.settings.tuiEngine == .auto ? .on : .off
        tuiMenu.addItem(.separator())
        for engine in AgentEngine.tuiCases + AgentEngine.cliCases {
            let found = session.installedEngines.contains { $0.engine == engine }
            let title = found
                ? engine.shortTitle
                : Copy.t("\(engine.shortTitle)（未安装）", "\(engine.shortTitle) (not installed)")
            let item = tuiMenu.addItem(withTitle: title, action: #selector(selectTUIEngine(_:)), keyEquivalent: "")
            item.representedObject = engine.rawValue
            item.target = self
            let selected = session.settings.selectedCustomID == nil
                && (session.settings.tuiEngine.engine == engine
                    || (session.settings.tuiEngine == .auto && session.presence.engine == engine))
            item.state = selected ? .on : .off
        }
        if session.settings.customRuntimes.isEmpty == false {
            tuiMenu.addItem(.separator())
            for custom in session.settings.customRuntimes {
                let found = session.installedEngines.contains { $0.runtimeKey == "custom:\(custom.id)" }
                let kind = custom.kind == .cli ? "CLI" : "TUI"
                let title = found ? "\(custom.title) · \(kind)" : Copy.t("\(custom.title)（未安装）", "\(custom.title) (not installed)")
                let item = tuiMenu.addItem(withTitle: title, action: #selector(selectCustomRuntime(_:)), keyEquivalent: "")
                item.representedObject = custom.id
                item.target = self
                item.state = session.settings.selectedCustomID == custom.id ? .on : .off
            }
        }
        let tuiItem = menu.addItem(withTitle: Copy.t("选择终端…", "Choose terminal…"), action: nil, keyEquivalent: "")
        menu.setSubmenu(tuiMenu, for: tuiItem)
        menu.addItem(withTitle: Copy.t("指定可执行文件…", "Choose executable…"), action: #selector(pickTUIExecutable), keyEquivalent: "")
        for engine in AgentEngine.tuiCases {
            let item = menu.addItem(
                withTitle: Copy.t("如何安装 \(engine.shortTitle)", "How to install \(engine.shortTitle)"),
                action: #selector(openEngineInstall(_:)),
                keyEquivalent: ""
            )
            item.representedObject = engine.rawValue
        }
        menu.addItem(withTitle: HotKeyCopy.menuCaptureTitle(captureOK: session.hotKeyCaptureOK), action: #selector(capturePage), keyEquivalent: "")
        menu.addItem(withTitle: HotKeyCopy.menuFilesTitle(filesOK: session.hotKeyFilesOK), action: #selector(admitFrontFiles), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: Copy.t("退出 DropAgent", "Quit DropAgent"), action: #selector(quit), keyEquivalent: "q")
        for item in menu.items {
            item.target = self
            if item.submenu == nil {
                item.isEnabled = item.action != nil
            }
        }
        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc func pickTUIExecutable() { session.pickTUIExecutable() }
    @objc func openEngineInstall(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let engine = AgentEngine(rawValue: raw)
        else { return }
        session.openTUIInstall(engine)
    }
    @objc func selectTUIAuto() { session.setTUIPreference(.auto) }
    @objc func selectTUIEngine(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let preference = TUIEnginePreference(rawValue: raw)
        else { return }
        session.setTUIPreference(preference)
    }
    @objc func selectCustomRuntime(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        session.setCustomRuntime(id)
    }
    @objc func capturePage() {
        Task { @MainActor [weak self] in
            self?.session.prepareCapture()
            self?.showPanel()
            await self?.session.captureCurrentPage()
        }
    }

    @objc func admitFrontFiles() {
        Task { @MainActor [weak self] in
            self?.session.prepareFrontFiles()
            self?.showPanel()
            await self?.session.admitFrontSelection()
        }
    }
    @objc func quit() { NSApp.terminate(nil) }
}
