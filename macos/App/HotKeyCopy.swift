import Foundation

@MainActor
enum HotKeyCopy {
    static func missingJobLine(tuiTitle: String) -> String {
        Copy.t(
            "\(tuiTitle) 没有无界面执行入口，动作不能跑。",
            "\(tuiTitle) has no headless entry, so recipes cannot run."
        )
    }

    static func recipeActorLine(hasRecipe: Bool, hasAgent: Bool, tuiTitle: String) -> String {
        if hasRecipe {
            return Copy.t("\(tuiTitle) 在任务副本里跑。", "\(tuiTitle) runs in a job copy.")
        }
        if hasAgent { return missingJobLine(tuiTitle: tuiTitle) }
        return Copy.t("未发现终端 Agent。", "No terminal agent found.")
    }

    static func recipeApprovalWaitLine(tuiTitle: String) -> String {
        Copy.t(
            "这里点不了同意。等 \(tuiTitle) 自己过，或取消。",
            "You cannot approve here. Wait for \(tuiTitle), or cancel."
        )
    }

    static func footer(hasAgent: Bool, tuiTitle: String, toggleOK: Bool, captureOK: Bool, filesOK: Bool = true) -> String {
        let first = hasAgent
            ? Copy.t(
                "发送进 \(tuiTitle) 终端，不是副本沙箱。文件可拖出或复制。",
                "Send goes into the \(tuiTitle) terminal, not the copy sandbox. Files can be dragged or copied."
            )
            : Copy.t("没有终端 Agent，只能先放架子。", "No terminal agent, so items can only sit on the shelf.")
        return first + "\n" + hotkeyLine(hasAgent: hasAgent, toggleOK: toggleOK, captureOK: captureOK, filesOK: filesOK)
    }

    static func hotkeyLine(hasAgent: Bool, toggleOK: Bool, captureOK: Bool, filesOK: Bool = true) -> String {
        let toggle = HotKeyCenter.shared.toggleChord.label
        let capture = HotKeyCenter.shared.captureChord.label
        let files = HotKeyCenter.shared.filesChord.label
        let filesBit = filesOK
            ? Copy.t("\(files) 加入选中文件。", "\(files) adds the selected files.")
            : Copy.t("加入文件的快捷键被占用。", "The add-files hotkey is taken.")
        let base: String
        switch (toggleOK, captureOK) {
        case (true, true):
            base = hasAgent
                ? Copy.t("\(toggle) 打开，\(capture) 抓当前页。", "\(toggle) opens the panel, \(capture) captures the current page.")
                : Copy.t("\(capture) 仍可抓当前页。", "\(capture) can still capture the current page.")
        case (false, true):
            base = Copy.t(
                "\(toggle) 被占用，点菜单栏图标打开。\(capture) 抓当前页。",
                "\(toggle) is taken; click the menu bar icon. \(capture) captures the current page."
            )
        case (true, false):
            base = Copy.t(
                "\(toggle) 打开。\(capture) 被占用，用菜单抓页。",
                "\(toggle) opens the panel. \(capture) is taken; capture from the menu."
            )
        case (false, false):
            base = Copy.t(
                "快捷键被占用。点菜单栏图标打开，用菜单抓页。",
                "Hotkeys are taken. Click the menu bar icon; capture from the menu."
            )
        }
        return base + " " + filesBit
    }

    static func menuFilesTitle(filesOK: Bool) -> String {
        filesOK
            ? Copy.t("加入选中的文件 (\(HotKeyCenter.shared.filesChord.label))", "Add selected files (\(HotKeyCenter.shared.filesChord.label))")
            : Copy.t("加入选中的文件", "Add selected files")
    }

    static func emptyHint(hasAgent: Bool, tuiTitle: String, captureOK: Bool) -> String {
        let paste = HotKeyCenter.shared.pasteChord.label
        let capture = HotKeyCenter.shared.captureChord.label
        if hasAgent {
            return Copy.t(
                "先放下，点 + 或搜索，\(paste) 粘贴，或拖到右侧发给 \(tuiTitle)",
                "Drop here, tap +, search, paste with \(paste), or drag right to send to \(tuiTitle)"
            )
        }
        return captureOK
            ? Copy.t(
                "没有终端也能先放着，\(paste) 粘贴，或 \(capture) 抓当前页",
                "You can still stage files, paste with \(paste), or capture with \(capture)"
            )
            : Copy.t(
                "没有终端也能先放着，\(paste) 粘贴，或用菜单抓当前页",
                "You can still stage files, paste with \(paste), or capture from the menu"
            )
    }

    static func workIdleHint(hasAgent: Bool, hasRecipe: Bool, tuiTitle: String, captureOK: Bool, hasItems: Bool) -> String {
        if hasAgent && hasRecipe {
            if hasItems {
                return Copy.t(
                    "点列表里的文件，或把文件拖进面板加入材料。发给 \(tuiTitle) 请用轮盘。",
                    "Click a file in the list, or drop files onto the panel to add them. Use the wheel to send to \(tuiTitle)."
                )
            }
            return Copy.t(
                "把文件拖进面板加入材料。发给 \(tuiTitle) 请用轮盘。",
                "Drop files onto the panel to add them. Use the wheel to send to \(tuiTitle)."
            )
        }
        if hasAgent {
            return Copy.t(
                "\(tuiTitle) 没有无界面执行入口。终端仍可发送。点右上角可换成有执行入口的 CLI。",
                "\(tuiTitle) has no headless entry. You can still send to the terminal. Use the chip to pick a CLI with an exec entry."
            )
        }
        return captureOK
            ? Copy.t(
                "未发现终端 Agent。仍可把文件放到左边，或 \(HotKeyCenter.shared.captureChord.label) 抓当前页。也可以点右上角选择已装的 TUI。",
                "No terminal agent found. You can still stage files on the left, or capture with \(HotKeyCenter.shared.captureChord.label). The chip can pick an installed TUI."
            )
            : Copy.t(
                "未发现终端 Agent。仍可把文件放到左边，或用菜单抓当前页。也可以点右上角选择已装的 TUI。",
                "No terminal agent found. You can still stage files on the left, or capture from the menu. The chip can pick an installed TUI."
            )
    }

    static func menuCaptureTitle(captureOK: Bool) -> String {
        captureOK
            ? Copy.t("抓取当前页 (\(HotKeyCenter.shared.captureChord.label))", "Capture current page (\(HotKeyCenter.shared.captureChord.label))")
            : Copy.t("抓取当前页", "Capture current page")
    }
}
