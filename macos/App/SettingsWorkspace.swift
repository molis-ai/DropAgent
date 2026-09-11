import SwiftUI

struct SettingsWorkspace: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsForm.sectionTitle(Copy.t("默认工作区", "Workspace"))
            SettingsForm.pathRow(
                title: Copy.t("写入区域", "Incoming files"),
                caption: Copy.t(
                    "保存添加的材料副本，原文件保持不变。",
                    "Stores copies of added files. Originals stay unchanged."
                ),
                path: DropAgentPaths.inbox,
                isOverride: session.prefs.inboxPath != nil,
                choose: { session.pickWorkspaceFolder(.inbox) },
                reset: { session.setWorkspaceFolder(.inbox, url: nil) }
            )
            SettingsForm.pathRow(
                title: Copy.t("输出结果", "Results"),
                caption: Copy.t(
                    "按任务保存生成的文件。",
                    "Stores generated files, organized by task."
                ),
                path: DropAgentPaths.jobs,
                isOverride: session.prefs.jobsPath != nil,
                choose: { session.pickWorkspaceFolder(.jobs) },
                reset: { session.setWorkspaceFolder(.jobs, url: nil) }
            )
        }
    }
}
