import SwiftUI

struct AcknowledgementsView: View {
    private let items: [Acknowledgement] = [
        .init(
            id: "swift",
            name: "Swift",
            license: "Apache License 2.0",
            description: "Apple's powerful programming language for iOS development."
        ),
        .init(
            id: "swiftui",
            name: "SwiftUI",
            license: "Apple Inc.",
            description: "Declarative UI framework for building native iOS applications."
        ),
        .init(
            id: "network_framework",
            name: "Network.framework",
            license: "Apple Inc.",
            description: "Modern networking framework for network path monitoring and connectivity."
        ),
        .init(
            id: "swiftdata",
            name: "SwiftData",
            license: "Apple Inc.",
            description: "Data persistence framework for storing app data."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("NetMonitor uses the following open-source libraries and technologies:")
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.bottom, 8)
                    .accessibilityIdentifier("acknowledgements_text_intro")

                ForEach(items) { item in
                    AcknowledgementItem(item: item)
                }

                Text("Special Thanks")
                    .font(.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .padding(.top, 8)
                    .accessibilityIdentifier("acknowledgements_heading_specialThanks")

                Text("Thanks to the iOS development community for their invaluable resources, tutorials, and support.")
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .accessibilityIdentifier("acknowledgements_text_specialThanks")
            }
            .padding()
        }
        .themedBackground()
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("screen_acknowledgements")
    }
}

private struct Acknowledgement: Identifiable {
    let id: String
    let name: String
    let license: String
    let description: String
}

private struct AcknowledgementItem: View {
    let item: Acknowledgement

    var body: some View {
        let prefix = "acknowledgements_item_\(item.id)"

        VStack(alignment: .leading, spacing: 8) {
            Text(item.name)
                .font(.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .accessibilityIdentifier("\(prefix)_name")

            Text(item.license)
                .font(.subheadline)
                .foregroundStyle(Theme.Colors.accent)
                .accessibilityIdentifier("\(prefix)_license")

            Text(item.description)
                .font(.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .accessibilityIdentifier("\(prefix)_description")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Colors.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(prefix)
    }
}

#Preview {
    NavigationStack {
        AcknowledgementsView()
    }
}
