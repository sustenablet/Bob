import SwiftUI

struct IconPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let symbols: [String]
    @Binding var selectedSymbol: String

    private let cols = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: cols, spacing: 12) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button {
                            selectedSymbol = symbol
                            dismiss()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selectedSymbol == symbol ? Color.bobAccent.opacity(0.2) : Color.bobSurface)
                                    .frame(height: 52)
                                Image(systemName: symbol)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(selectedSymbol == symbol ? Color.bobAccent : Color.bobInk2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .background(Color.bobBackground)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                    }
                }
            }
        }
    }
}

