import SwiftUI

struct MascotCharacterView: View {
    let state: PetState
    var size: CGFloat = 80

    var body: some View {
        PetCharacter(state: state, size: size)
    }
}
