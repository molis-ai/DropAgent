import DropAgentJob
import SwiftUI

struct RecipeConfirmationView: View {
    @ObservedObject var session: AppSession

    var body: some View {
        let batch = session.selectedItems.filter { $0.status == .confirm }
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Copy.t("\(batch.count) 项", "\(batch.count) items"))
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
                Text("\(Copy.recipeStored(batch.first?.recipe))\(optionSuffix)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            if let recipe = session.confirmRecipeID {
                RecipeOptionChips(session: session, recipe: recipe)
            }
            RecipeFacts(
                count: batch.count,
                write: session.recipeWriteFact,
                network: session.recipeNetworkFact,
                isolation: session.recipeIsolationFact
            )
            HStack(spacing: 12) {
                Button { Task { await session.confirmRun() } } label: {
                    HStack(spacing: 6) {
                        Text(Copy.t("在副本中运行", "Run on a copy"))
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(!session.canConfirmRun || !session.runningItems.isEmpty)
                .accessibilityIdentifier("confirm-run")
                Button { session.cancelConfirm() } label: {
                    Text(Copy.t("取消", "Cancel"))
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cancel-confirm")
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
