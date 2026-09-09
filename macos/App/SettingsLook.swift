import SwiftUI

struct SettingsLook: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                SettingsForm.sectionTitle(Copy.t("颜色", "Theme"))
                SettingsForm.segmented(
                    items: [
                        (AppearancePreference.light, Copy.t("浅色", "Light")),
                        (.dark, Copy.t("深色", "Dark")),
                        (.system, Copy.t("跟随系统", "System")),
                    ],
                    selected: session.prefs.appearance
                ) { session.setAppearance($0) }
            }
            VStack(alignment: .leading, spacing: 10) {
                SettingsForm.sectionTitle(Copy.t("语言", "Language"))
                SettingsForm.segmented(
                    items: [
                        (AppLanguage.zh, "中文"),
                        (.en, "English"),
                        (.system, Copy.t("跟随系统", "System")),
                    ],
                    selected: session.prefs.language
                ) { session.setLanguage($0) }
            }
            VStack(alignment: .leading, spacing: 10) {
                SettingsForm.sectionTitle(Copy.t("拖放", "Drop"))
                SettingsForm.toggleRow(
                    title: Copy.t("拖文件时显示轮盘", "Show drop wheel while dragging"),
                    caption: Copy.t("关掉后，仍可拖到菜单栏图标和文件行。", "The menu bar icon and file row still accept drops."),
                    isOn: session.prefs.showDropWheel,
                    identifier: "settings-show-wheel"
                ) { session.setShowDropWheel($0) }
            }
        }
    }
}
