import SwiftUI

struct SettingsGuide: View {
    @ObservedObject var session: AppSession

    var body: some View {
        let _ = session.prefs.language
        VStack(alignment: .leading, spacing: 12) {
            SettingsForm.sectionTitle(Copy.t("能做什么", "How It Works"))
            SettingsForm.guideCard(title: SettingsGuideCopy.dropInTitle, body: SettingsGuideCopy.dropIn)
            SettingsForm.guideCard(title: SettingsGuideCopy.filesTitle, body: SettingsGuideCopy.files)
            SettingsForm.guideCard(title: SettingsGuideCopy.acceptsTitle, body: SettingsGuideCopy.accepts)
            SettingsForm.guideCard(title: SettingsGuideCopy.browserTitle, body: SettingsGuideCopy.browser)
            SettingsForm.guideCard(title: SettingsGuideCopy.readsTitle, body: SettingsGuideCopy.reads)
            SettingsForm.guideCard(title: SettingsGuideCopy.writesTitle, body: SettingsGuideCopy.writes)
            SettingsForm.guideCard(title: SettingsGuideCopy.dropOutTitle, body: SettingsGuideCopy.dropOut)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings-guide")
    }
}
