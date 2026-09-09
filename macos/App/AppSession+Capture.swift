import AppKit
import DropAgentIngest
import Foundation

extension AppSession {
    static let captureFailedCopy = PageAdmitCopy.needAccessibility

    func prepareCapture() {
        lastCaptureToken = PageAdmitToken.snapshot()
        isCapturing = true
        errorText = nil
        offerPrivacySettings = false
        offerCaptureRetry = false
        aiTab = .work
    }

    func captureCurrentPage(token: PageAdmitToken) async {
        lastCaptureToken = token
        isCapturing = true
        errorText = nil
        offerPrivacySettings = false
        offerCaptureRetry = false
        aiTab = .work
        await captureCurrentPage()
    }

    func captureCurrentPage() async {
        guard authorizingID == nil else {
            isCapturing = false
            return
        }
        if isCapturing == false {
            prepareCapture()
        }
        let token = lastCaptureToken ?? .snapshot()
        let isCLI = ProcessInfo.processInfo.arguments.contains("--capture")
        if isCLI == false {
            let decision = await PageAdmit.decideOffMain(token: token)
            if decision.proceed == false {
                if decision.promptAccessibility {
                    PageAdmit.requestTrustIfNeeded()
                }
                errorText = captureCopy(decision.message)
                offerPrivacySettings = decision.offerPrivacySettings
                offerCaptureRetry = true
                aiTab = .work
                isCapturing = false
                return
            }
        }
        do {
            let item = try await ingest.admitCurrentPage(token: token)
            shelf.setSelection([item.id])
            errorText = nil
            offerPrivacySettings = false
            offerCaptureRetry = false
            aiTab = .work
        } catch {
            let failed = await PageAdmit.failureOffMain(token: token)
            errorText = captureCopy(failed.message)
            offerPrivacySettings = failed.offerPrivacySettings
            offerCaptureRetry = true
            aiTab = .work
        }
        isCapturing = false
    }

    private func captureCopy(_ message: String) -> String {
        if message == PageAdmitCopy.noBrowser, hotKeyCaptureOK {
            let key = prefs.captureHotKey.label
            return Copy.t(
                "没读到当前页。把 Safari、Chrome 或 Edge 放到最前面，再按 \(key)。",
                "No current page. Bring Safari, Chrome, or Edge to the front, then press \(key)."
            )
        }
        return message
    }
}
