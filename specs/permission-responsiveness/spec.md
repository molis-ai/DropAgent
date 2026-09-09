# Permission responsiveness and truthful status

## Background and evidence
Recording a real workflow exposed a hang when authorizing automation. A 3-second sample of PID 25042 on 2026-09-08 shows every main-thread sample waiting inside AEDeterminePermissionToAutomateTarget, called by AppSession.authorizeBrowserRow. System Settings shows Accessibility enabled, while the application previously showed an untrusted/foreign-copy message. The exact identity mismatch is not proven.

## Scope and completion level
Target: functional fix, with packaged-app verification where environment allows. Fix automation requests (settings and Finder admission), asynchronous status refresh, honest bilingual status and accessibility guidance. Preserve current unrelated multi-drag changes. No resetting privacy permissions, automatic permission grants, certificate installation, or changed file/job semantics.

## Behavior and decisions
- Blocking permission work runs off the main thread in the application process so consent still belongs to DropAgent.
- Keep allowed, denied, notDetermined and unavailable distinct; do not claim a silent denial proves the user explicitly refused.
- One authorization per session and one status refresh in flight. A pending system prompt cannot freeze UI or queue repeated requests. Show waiting/recovery guidance and let users open system settings.
- Refresh after authorization and on activation/settings observation. During a pending authorization keep accessibility status live; preserve prior automation status with explicit pending indication.
- Do not infer that the system toggle is off from process trust alone, or that another instance caused trust failure. Show current executable location to identify the installed copy.
- Remove the extra AppleScript consent-ping fallback; one native consent request determines the result.

## Modules and dependencies
Capture: permission worker, AutomationAccess, AccessibilityPage. Ingest: async permission boundary. App: session refresh/request lifecycle and SetupChecklist/SetupCopy. Check: status mapping and a simulated blocked permission operation that verifies main-actor responsiveness. Existing Swift 6/AppKit stack; no dependencies.

## Acceptance and validation
1. Waiting permission operation runs off main thread and main actor remains responsive; test using a gated blocking operation and actual production worker.
2. Denied and unavailable states survive mapping and show distinct bilingual guidance.
3. Completion triggers fresh state; repeated clicks/refreshes are coalesced.
4. Settings remain navigable, language switching works in packaged app, and real consent completion updates state if authorized by user.
5. Original materials and unrelated working changes are untouched.
Commands: cd macos && swift run DropAgentCheck; swift build --product DropAgent; bash macos/package-app.sh. Review scoped diff and smoke-test packaged settings.

## Open questions
Whether current system Accessibility entry matches the running binary cannot be proven by the toggle label alone. Current bundle is adhoc signed. Do not claim that identity issue is fixed without real process-trust validation; stable distribution signing remains outside this task.

Inspection found synchronous permission probes in capture preflight/recovery and Finder admission. Include their async wrappers so the same blocking API cannot re-enter the main thread through these upstream consumers.

Live QA caught layout jumping because periodic refresh inserted/removed a status row. Loading text must appear only during initial load; unchanged permission snapshots must not be republished. Verify stable settings layout over successive refreshes.

## Verification results (2026-09-08)
- PASS: Swift build and package-app; current dist/DropAgent.app replaced in place.
- PASS: DropAgentCheck all passed, including denied-state preservation and actual blocked PermissionWork/main-actor responsiveness test. Live capture in this general suite reported captureFailed; this is not a successful browser-capture validation.
- PASS: packaged app Finder/Safari rows show allowed; Chrome shows notDetermined. Triggering Chrome consent shows waiting, then long-wait guidance; navigating Appearance and switching Chinese/English works while the OS request is pending.
- PASS: periodic polling no longer inserts/removes loading text after first load, no published polling flag, unchanged permission snapshots are not republished. Reopened packaged app inspected with CUA.
- PASS: prior main-thread sample blocked in AE permission API; post-fix startup sample shows a normal AppKit event loop. Real pending consent tested with interactive navigation.
- OPEN: Chrome consent has not yet returned; user asked whether a system dialog is visible. Successful consent completion and subsequent permission refresh not yet verified live.
- OPEN: System Settings Accessibility toggle is enabled, but process AX trust remains false. No TCC reset or automatic grants performed. Current package remains adhoc-signed; app identity mismatch is not proven.
- Preserved unrelated multi-drag work; no commit made.

Follow-up live verification: user completed Chrome consent. The waiting state cleared and Chrome changed to allowed without code intervention. Relaunch retained Chrome/Finder/Safari allowed. Accessibility still reports untrusted after relaunch; exact application-entry reauthorization remains required for live capture verification.

Final permission follow-up: after user re-added the current application to Accessibility, packaged settings updated to Accessibility enabled, with Finder/Safari/Chrome all allowed. No additional rebuild or permission reset was performed. Browser shortcut attempt did not establish a successful capture, so capture/recording remain a separate pending workflow validation.
