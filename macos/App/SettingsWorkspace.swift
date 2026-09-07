import SwiftUI

struct SettingsWorkspace: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SettingsForm.sectionTitle(Copy.t("默认工作区", "Workspace"))
            SettingsForm.pathRow(
                title: Copy.t("写入区域", "Incoming files"),
                caption: Copy.t(
                    "拖进来的文件副本放在这里。原件不动。",
                    "Staged copies of dropped files live here. Originals stay put."
                ),
                path: DropAgentPaths.inbox,
                isOverride: session.prefs.inboxPath != nil,
                choose: { session.pickWorkspaceFolder(.inbox) },
                reset: { session.setWorkspaceFolder(.inbox, url: nil) }
            )
            SettingsForm.pathRow(
                title: Copy.t("输出结果", "Results"),
                caption: Copy.t(
                    "Recipe 跑完的新文件放在这里，目录是任务编号 / output。",
                    "New files from recipes land here, under each job id / output."
                ),
                path: DropAgentPaths.jobs,
                isOverride: session.prefs.jobsPath != nil,
                choose: { session.pickWorkspaceFolder(.jobs) },
                reset: { session.setWorkspaceFolder(.jobs, url: nil) }
            )
        }
    }
}
