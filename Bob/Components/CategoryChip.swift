import SwiftUI

struct CategoryChip: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.sfSymbol)
                    .font(.system(size: 13, weight: .medium))
                Text(category.name)
                    .font(.bobBody)
            }
            .foregroundStyle(isSelected ? Color.bobAccent : Color.bobInk2)
            .padding(.horizontal, Spacing.s)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .fill(isSelected ? Color.bobAccentSoft : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 999, style: .continuous)
                    .stroke(isSelected ? Color.bobAccent.opacity(0.4) : Color.bobHairline, lineWidth: Hairline.width)
            )
        }
        .buttonStyle(.plain)
    }
}
