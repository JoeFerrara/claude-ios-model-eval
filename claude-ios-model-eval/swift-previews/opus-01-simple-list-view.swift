import SwiftUI

// MARK: - Model

struct Contact: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var phoneNumber: String
    var email: String

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.count > 1 ? parts.last!.prefix(1) : ""
        return "\(first)\(last)".uppercased()
    }
}

// MARK: - View Model

@Observable
class ContactStore {
    var contacts: [Contact] = [
        Contact(name: "Alice Johnson", phoneNumber: "(555) 123-4567", email: "alice@example.com"),
        Contact(name: "Bob Smith", phoneNumber: "(555) 234-5678", email: "bob@example.com"),
        Contact(name: "Carol Williams", phoneNumber: "(555) 345-6789", email: "carol@example.com"),
        Contact(name: "David Brown", phoneNumber: "(555) 456-7890", email: "david@example.com"),
        Contact(name: "Eva Martinez", phoneNumber: "(555) 567-8901", email: "eva@example.com"),
        Contact(name: "Frank Lee", phoneNumber: "(555) 678-9012", email: "frank@example.com"),
    ]

    var searchText = ""

    var filteredContacts: [Contact] {
        if searchText.isEmpty { return contacts }
        return contacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let initials: String
    var size: CGFloat = 44

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.blue.gradient)
            .clipShape(Circle())
    }
}

// MARK: - Contact List View

struct ContactListView: View {
    @State private var store = ContactStore()

    var body: some View {
        NavigationStack {
            List(store.filteredContacts) { contact in
                NavigationLink(value: contact) {
                    HStack(spacing: 12) {
                        AvatarView(initials: contact.initials)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name)
                                .font(.body.weight(.medium))
                            Text(contact.phoneNumber)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Contacts")
            .searchable(text: $store.searchText, prompt: "Search by name")
            .navigationDestination(for: Contact.self) { contact in
                ContactDetailView(contact: contact)
            }
        }
    }
}

// MARK: - Contact Detail View

struct ContactDetailView: View {
    let contact: Contact

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        AvatarView(initials: contact.initials, size: 80)
                        Text(contact.name)
                            .font(.title2.weight(.semibold))
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Phone") {
                Label(contact.phoneNumber, systemImage: "phone.fill")
            }

            Section("Email") {
                Label(contact.email, systemImage: "envelope.fill")
            }
        }
        .navigationTitle(contact.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

#Preview {
    ContactListView()
}

