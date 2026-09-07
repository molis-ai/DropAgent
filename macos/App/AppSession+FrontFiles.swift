import AppKit
import DropAgentIngest
import Foundation

extension AppSession {
    func prepareFrontFiles() {
        let front = NSWorkspace.shared.frontmostApplication
        lastFrontBundle = front?.bundleIdentifier
        lastFrontPID = front?.processIdentifier ?? 0
        hasFrozenFront = true
    }

    func admitFrontSelection() async {
        guard isCapturing == false, isAdmittingFiles == false else { return }
        isAdmittingFiles = true
        errorText = nil
        offerPrivacySettings = false
        offerCaptureRetry = false
        retryFrontFiles = true
        filesPrivacy = .none
        aiTab = .work
        if hasFrozenFront == false {
            prepareFrontFiles()
        }
        hasFrozenFront = false
        let bundle = lastFrontBundle
        let pid = lastFrontPID
        let kind = FrontAdmit.classify(bundleID: bundle)
        var ax = PageAdmit.isTrusted()
        var finderOK = FrontAdmit.finderAllowed()
        if case .failure(let fail) = FrontAdmit.decide(kind: kind, axTrusted: ax, finderAllowed: finderOK) {
            if fail == .needAccessibility {
                PageAdmit.requestTrustIfNeeded()
                ax = PageAdmit.isTrusted()
            }
            if fail == .needFinderAutomation {
                _ = PageAdmit.requestAutomation(bundleIdentifier: FrontAdmit.finderBundleID)
                finderOK = FrontAdmit.finderAllowed()
            }
        }
        if case .failure(let fail) = FrontAdmit.decide(kind: kind, axTrusted: ax, finderAllowed: finderOK) {
            presentFilesFailure(fail)
            isAdmittingFiles = false
            return
        }
        switch await FrontAdmit.collect(frontBundleID: bundle, frontPID: pid) {
        case .success(let read):
            let result = ingest.admit(urls: read.urls)
            follow(result)
            if result.admitted.isEmpty == false {
                shelf.setSelection(Set(result.admitted.map(\.id)))
                errorText = nil
                offerPrivacySettings = false
                offerCaptureRetry = false
                retryFrontFiles = false
                filesPrivacy = .none
            } else if errorText == nil {
                presentFilesFailure(.empty)
            }
            aiTab = .work
        case .failure(let fail):
            presentFilesFailure(fail)
        }
        isAdmittingFiles = false
    }

    private func presentFilesFailure(_ fail: FrontAdmitError) {
        offerCaptureRetry = true
        retryFrontFiles = true
        switch fail {
        case .selfApp:
            errorText = Copy.t("到 Finder 或编辑器里选中文件再按。", "Select files in Finder or an editor, then press the shortcut.")
            offerPrivacySettings = false
            filesPrivacy = .none
        case .browser:
            let key = prefs.captureHotKey.label
            errorText = Copy.t(
                "这不是文件。网页请用 \(key)。",
                "That is not a file. Capture a page with \(key)."
            )
            offerPrivacySettings = false
            filesPrivacy = .none
        case .needAccessibility:
            errorText = Copy.t("加入选中文件需要辅助功能。", "Adding selected files needs Accessibility.")
            offerPrivacySettings = true
            filesPrivacy = .accessibility
        case .needFinderAutomation:
            errorText = Copy.t(
                "加入 Finder 里选中的文件需要允许控制 Finder。",
                "Adding Finder selection needs control of Finder."
            )
            offerPrivacySettings = true
            filesPrivacy = .finder
        case .emptyFinder:
            errorText = Copy.t("请先在 Finder 里选中文件。", "Select files in Finder first.")
            offerPrivacySettings = false
            filesPrivacy = .none
        case .empty:
            errorText = Copy.t(
                "没读到选中的文件。可在 Finder 里选，或打开一个本地文件。",
                "No selected files. Select in Finder, or open a local file."
            )
            offerPrivacySettings = PageAdmit.isTrusted() == false
            filesPrivacy = offerPrivacySettings ? .accessibility : .none
        }
    }
}
