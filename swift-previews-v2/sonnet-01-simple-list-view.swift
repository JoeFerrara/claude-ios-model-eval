import SwiftUI

// MARK: - Model

struct Contact: Identifiable {
    let id = UUID()
    let name: String
    let phone: String

    var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
    }
}

// MARK: - Store

@Observable
final class ContactStore {
    var contacts: [Contact] = [
        Contact(name: "Alice Johnson",  phone: "555-0101"),
        Contact(name: "Bob Smith",      phone: "555-0102"),
        Contact(name: "Carol White",    phone: "555-0103"),
        Contact(name: "David Brown",    phone: "555-0104"),
        Contact(name: "Eva Martinez",   phone: "555-0105"),
        Contact(name: "Frank Lee",      phone: "555-0106"),
        Contact(name: "Grace Kim",      phone: "555-0107"),
        Contact(name: "Henry Davis",    phone: "555-0108"),
    ]
}

// MARK: - Avatar Color Helper

private let avatarPalette: [Color] = [
    .blue, .purple, .orange, .green, .pink, .teal, .indigo, .red
]

private func avatarColor(for name: String) -> Color {
    avatarPalette[abs(name.hashValue) % avatarPalette.count]
}

// MARK: - InitialsAvatar

struct InitialsAvatar: View {
    let initials: String
    let diameter: CGFloat
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: diameter, height: diameter)
            .overlay(
                Text(initials)
                    .font(.system(size: diameter * 0.38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            )
    }
}

// MARK: - ContactDetailView

struct ContactDetailView: View {
    let contact: Contact

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        InitialsAvatar(
                            initials: contact.initials,
                            diameter: 90,
                            color: avatarColor(for: contact.name)
                        )
                        Text(contact.name)
                            .font(.title2.bold())
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .padding(.vertical, 8)
            }

            Section("Contact Info") {
                LabeledContent("Phone", value: contact.phone)
            }
        }
        .navigationTitle(contact.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - ContactListView

struct ContactListView: View {
    @State private var store = ContactStore()
    @State private var searchText = ""

    private var filtered: [Contact] {
        guard !searchText.isEmpty else { return store.contacts }
        return store.contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { contact in
                NavigationLink {
                    ContactDetailView(contact: contact)
                } label: {
                    HStack(spacing: 14) {
                        InitialsAvatar(
                            initials: contact.initials,
                            diameter: 46,
                            color: avatarColor(for: contact.name)
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                                .font(.body)
                            Text(contact.phone)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .searchable(text: $searchText, prompt: "Search contacts")
            .navigationTitle("Contacts")
        }
    }
}

// MARK: - App Entry Point

@main
struct ContactsApp: App {
    var body: some Scene {
        WindowGroup {
            ContactListView()
        }
    }
}

