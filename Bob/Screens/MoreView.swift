import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.bobBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Spacing.m) {
                        pageHeader
                        moreLinks
                    }
                    .padding(.horizontal, Spacing.pageMargin)
                    .padding(.top, Spacing.m)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("More")
                    .font(.system(size: 28, weight: .bold)).foregroundStyle(Color.bobInk)
                Text("Settings & extras")
                    .font(.system(size: 14)).foregroundStyle(Color.bobInk2)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    private var moreLinks: some View {
        VStack(spacing: 0) {
            moreRow(icon: "target", iconColor: Color.bobAccent, label: "Savings Goals") {
                // Navigate to goals
            }
            Divider().background(Color.bobHairline)
            moreRow(icon: "list.bullet.rectangle", iconColor: Color.bobChartBlue, label: "All Transactions") {
                // Navigate to transactions
            }
            Divider().background(Color.bobHairline)
            moreRow(icon: "gearshape.fill", iconColor: Color.bobInk2, label: "Settings") {
                // Navigate to settings
            }
        }
        .background(Color.bobSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.bobHairline, lineWidth: 1))
    }

    private func moreRow(icon: String, iconColor: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(iconColor.opacity(0.2)).frame(width: 34, height: 34)
                    Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(iconColor)
                }
                Text(label).font(.bobBody).foregroundStyle(Color.bobInk)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.bobInk2)
            }
            .padding(.horizontal, Spacing.m).padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
