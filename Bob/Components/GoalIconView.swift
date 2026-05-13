import SwiftUI

struct GoalIconView: View {
    let iconName: String
    let photoData: Data?
    var size: CGFloat = 24
    var accentColor: Color = .bobAccent
    var showBackground: Bool = true

    var body: some View {
        if let data = photoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            Image(systemName: iconName)
                .font(.system(size: size * 0.55, weight: .medium))
                .foregroundStyle(accentColor)
                .frame(width: size, height: size)
                .background {
                    if showBackground {
                        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                            .fill(accentColor.opacity(0.12))
                    }
                }
        }
    }
}
