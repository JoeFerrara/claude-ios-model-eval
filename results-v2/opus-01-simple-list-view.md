```swift
import SwiftUI

// MARK: - Model

struct Contact: Identifiable {
    let id = UUID()
    let firstName: String
    let lastName: String
    let phoneNumber: String
    let email: String

    var fullName: String { "\(firstName) \(lastName)" }

    var initials: String {
        let first = firstName.prefix(1)
        let last = lastName.prefix(1)
        return "\(first)\(last)".uppercased()
    }
}

// MARK: - State

@Observable
class ContactStore {
    var contacts: [Contact] = [
        Contact(firstName: "Alice", lastName: "Johnson", phoneNumber: "(555) 123-4567", email: "alice@example.com"),
        Contact(firstName: "Bob", lastName: "Smith", phoneNumber: "(555) 234-5678", email: "bob@example.com"),
        Contact(firstName: "Carol", lastName: "Williams", phoneNumber: "(555) 345-6789", email: "carol@example.com"),
        Contact(firstName: "David", lastName: "Brown", phoneNumber: "(555) 456-7890", email: "david@example.com"),
        Contact(firstName: "Eve", lastName: "Davis", phoneNumber: "(555) 567-8901", email: "eve@example.com"),
        Contact(firstName: "Frank", lastName: "Miller", phoneNumber: "(555) 678-9012", email: "frank@example.com"),
        Contact(firstName: "Grace", lastName: "Wilson", phoneNumber: "(555) 789-0123", email: "grace@example.com"),
        Contact(firstName: "Hank", lastName: "Moore", phoneNumber: "(555) 890-1234", email: "hank@example.com"),
    ]

    var searchText = ""

    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { $0.fullName.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let initials: String
    var size: CGFloat = 44

    private var color: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo, .mint]
        let hash = abs(initials.hashValue)
        return colors[hash % colors.count]
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient)
            .clipShape(Circle())
    }
}

// MARK: - Contact List

struct ContactListView: View {
    @State private var store = ContactStore()

    var body: some View {
        NavigationStack {
            List(store.filteredContacts) { contact in
                NavigationLink(value: contact.id) {
                    HStack(spacing: 14) {
                        AvatarView(initials: contact.initials)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.fullName)
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
            .navigationDestination(for: UUID.self) { id in
                if let contact = store.contacts.first(where: { $0.id == id }) {
                    ContactDetailView(contact: contact)
                }
            }
        }
    }
}

// MARK: - Contact Detail

struct ContactDetailView: View {
    let contact: Contact

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    AvatarView(initials: contact.initials, size: 80)
                    Text(contact.fullName)
                        .font(.title2.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .padding(.vertical, 8)
            }

            Section("Phone") {
                Label(contact.phoneNumber, systemImage: "phone.fill")
            }

            Section("Email") {
                Label(contact.email, systemImage: "envelope.fill")
            }
        }
        .navigationTitle(contact.fullName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - App Entry

@main
struct ContactsApp: App {
    var body: some Scene {
        WindowGroup {
            ContactListView()
        }
    }
}
```

**Key decisions:**

- **`@Observable`** on `ContactStore` — no need for `@Published`; SwiftUI tracks property access automatically (iOS 17+).
- **`NavigationStack` + `navigationDestination(for:)`** — type-safe navigation using the contact's `UUID`.
- **`AvatarView`** picks a deterministic gradient color from the initials hash so each contact gets a consistent color.
- **`searchable`** modifier wires the search bar; filtering happens in a computed property on the store.
- Everything compiles as a single-file iOS app target — just drop it into an Xcode project with a deployment target of iOS 17+.
