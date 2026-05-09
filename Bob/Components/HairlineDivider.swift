import SwiftUI

struct HairlineDivider: View {
    var color: Color = .bobHairline

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: Hairline.width)
    }
}
