import DropAgentJob
import SwiftUI

struct RecipeConfirmationView: View {
    @ObservedObject var session: AppSession

    var body: some View {
        let batch = session.selectedItems.filter { $0.status == .confirm }
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(session.displayedActionName(batch.first?.recipe))\(optionSuffix)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Text(Copy.t("\(batch.count) 份材料", "\(batch.count) materials"))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
            }
            Text(outputDescription)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            if let recipe = session.confirmRecipeID,
               RecipeCatalog.choices(for: recipe).choices.isEmpty == false
            {
                RecipeOptionChips(session: session, recipe: recipe)
            }
            RecipeFacts(
                count: batch.count,
                write: session.recipeWriteFact,
                network: session.recipeNetworkFact,
                isolation: session.recipeIsolationFact
            )
            HStack(spacing: 8) {
                Button { Task { await session.confirmRun() } } label: {
                    HStack(spacing: 6) {
                        Text(session.confirmRecipeID == .pdfText || session.confirmRecipeID == .imageText
                             ? Copy.t("开始提取", "Start extraction") : Copy.t("开始处理", "Run action"))
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!session.canConfirmRun || !session.runningItems.isEmpty)
                .accessibilityIdentifier("confirm-run")
                Button { session.cancelConfirm() } label: {
                    Text(Copy.t("返回", "Back"))
                }
                .buttonStyle(QuietButtonStyle())
                .accessibilityIdentifier("cancel-confirm")
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var outputDescription: String {
        if let recipe = session.confirmRecipeID, recipe != .shortcut {
            let name = RecipeCatalog.spec(recipe).outputFileName
            return Copy.t("将生成 \(name)。原文件保持不变。", "Creates \(name). Your original file stays unchanged.")
        }
        return Copy.t("将在结果区生成一个新文件。原文件保持不变。", "Creates a new file in Results. Your original stays unchanged.")
    }

    private var optionSuffix: String {
        guard let recipe = session.confirmRecipeID else { return "" }
        let current = session.choiceID(for: recipe)
        if let title = RecipeCatalog.choices(for: recipe).choices.first(where: { $0.id == current })?.title {
            return " · \(title)"
        }
        return ""
    }
}
