import AppKit
import DropAgentAgent
import DropAgentShelf
import DropAgentTUI
import Foundation

extension AppSession {
    func sendToTUI(itemIDs: [ItemID]? = nil) {
        flushStageEdit()
        guard canSendToTUI, presence.executable != nil else {
            if hasAgent == false {
                errorText = Copy.t("未发现终端 Agent。文件已留在架子上。", "No terminal agent found. Files stayed on the shelf.")
            }
            return
        }
        if paneFocus == .result, let record = selectedResult, let file = record.output {
            sendResultToTUI(record, file: file)
            return
        }
        let ids = itemIDs ?? selectedItems.map(\.id)
        do {
            let prepared = try tui.send(itemIDs: ids, text: promptText, sessionDirectory: tuiSessionDirectory)
            if ttyLines.isEmpty {
                ttyLines.append(TTYLine(kind: "sys", text: Copy.t("\(presence.shortTitle)  ·  本机会话", "\(presence.shortTitle)  ·  this Mac")))
            }
            for id in ids {
                if let item = shelf.item(id: id) {
                    ttyLines.append(TTYLine(kind: "file", text: Copy.t("材料  \(item.title)", "Material  \(item.title)")))
                }
            }
            let shown = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
            ttyLines.append(TTYLine(kind: "in", text: shown.isEmpty ? Copy.t("›  （没有附带说明）", "›  (no extra note)") : "›  \(shown)"))
            promptText = ""
            pendingTUI = prepared
            tuiSessionDirectory = prepared.cwd
            otherOpen = true
            aiTab = .tty
        } catch {
            errorText = human(error)
        }
    }

    private func sendResultToTUI(_ record: ResultRecord, file: URL) {
        do {
            let prepared = try tui.send(
                itemIDs: [],
                text: promptText,
                sessionDirectory: tuiSessionDirectory,
                extraFiles: [file]
            )
            if ttyLines.isEmpty {
                ttyLines.append(TTYLine(kind: "sys", text: Copy.t("\(presence.shortTitle)  ·  本机会话", "\(presence.shortTitle)  ·  this Mac")))
            }
            ttyLines.append(TTYLine(kind: "file", text: Copy.t("结果  \(record.title)", "Result  \(record.title)")))
            let shown = promptText.trimmingCharacters(in: .whitespacesAndNewlines)
            ttyLines.append(TTYLine(kind: "in", text: shown.isEmpty ? Copy.t("›  （没有附带说明）", "›  (no extra note)") : "›  \(shown)"))
            promptText = ""
            pendingTUI = prepared
            tuiSessionDirectory = prepared.cwd
            otherOpen = true
            aiTab = .tty
        } catch {
            errorText = human(error)
        }
    }

    func tuiProcessExited() {
        tuiProcessRunning = false
        ptyLive = false
        tuiSessionDirectory = nil
    }

    func failTUILaunch(itemIDs: [ItemID]) {
        tui.revertSend(itemIDs: itemIDs)
        errorText = Copy.t("没能打开 \(tuiTitle) 终端。", "Could not open the \(tuiTitle) terminal.")
        pendingTUI = nil
        tuiProcessExited()
    }

    func resetTUISession() {
        tuiSessionDirectory = nil
        pendingTUI = nil
        tuiProcessRunning = false
        ptyLive = false
        ttyLines = []
        tuiEpoch = UUID()
        refreshPresence()
    }

    func openTUIInstall(_ engine: AgentEngine?) {
        let target = engine ?? presence.engine ?? installedEngines.first?.engine ?? .grok
        NSWorkspace.shared.open(target.installURL)
    }

    var tuiCaption: String {
        if let file = ttyLines.last(where: { $0.kind == "file" }) {
            let name = file.text
                .replacingOccurrences(of: "材料  ", with: "")
                .replacingOccurrences(of: "Material  ", with: "")
                .replacingOccurrences(of: "结果  ", with: "")
                .replacingOccurrences(of: "Result  ", with: "")
            return "\(tuiTitle) · \(name)"
        }
        return ttyLines.last(where: { $0.kind == "sys" })?.text
            ?? Copy.t("\(tuiTitle)  ·  本机会话", "\(tuiTitle)  ·  this Mac")
    }
}
