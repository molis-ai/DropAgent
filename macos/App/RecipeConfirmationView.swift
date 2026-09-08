import DropAgentJob
import SwiftUI

struct RecipeConfirmationView: View {
    @ObservedObject var session: AppSession

    var body: some View {
        let batch = session.selectedItems.filter { $0.status == .confirm }
        VStack(alignment: .leading, spacing: 20) {
            Button { session.cancelConfirm() } label: {
                Label(Copy.t("返回动作", "Back to actions"), systemImage: "chevron.left")
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.muted)
            .padding(.vertical, 3)
            .accessibilityIdentifier("cancel-confirm")
            VStack(alignment: .leading, spacing: 8) {
                Text(Copy.recipeStored(batch.first?.recipe))
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Palette.text)
                Label(batch.map(\.title).joined(separator: "、"), systemImage: "doc.on.doc")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)
                    .help(batch.map(\.title).joined(separator: "\n"))
            }
            if let recipe = session.confirmRecipeID {
                RecipeOptionChips(session: session, recipe: recipe)
            }
            RecipeFacts(count: batch.count, write: session.recipeWriteFact,
                        network: session.recipeNetworkFact, isolation: session.recipeIsolationFact)
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                Text(session.recipeActorLine)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { Task { await session.confirmRun() } } label: {
                    HStack {
                        Text(Copy.t("在副本中运行", "Run on a copy"))
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .padding(.horizontal, 14)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!session.hasRecipe || !session.runningItems.isEmpty)
                .accessibilityIdentifier("confirm-run")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
