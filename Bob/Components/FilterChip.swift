import SwiftUI

/// Dropdown-style filter chip with an optional leading icon and selection state.
struct FilterChip: View {
    let text: String
    var systemImage: String? = nil
    var isSelected: Bool = false
    var onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 8) {
                if let icon = systemImage {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(isSelected ? Color.bobAccent : Color.bobInk2)
                }
                Text(text)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.bobAccent : Color.bobInk)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.bobAccent : Color.bobInk2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.bobAccent.opacity(0.08) : Color.bobSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.bobAccent.opacity(0.4) : Color.bobHairline, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
