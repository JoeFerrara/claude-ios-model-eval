```swift
import SwiftUI

// MARK: - Model

@Observable
class Contact: Identifiable {
    let id = UUID()
    var name: String
    var phone: String

    init(name: String, phone: String) {
        self.name = name
        self.phone = phone
    }

    var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }

    // Deterministic color based on name
    var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .teal, .indigo, .mint, .cyan]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
}

// MARK: - Store

@Observable
class ContactStore {
    var contacts: [Contact] = [
        Contact(name: "Alice Johnson", phone: "(555) 123-4567"),
        Contact(name: "Bob Martinez", phone: "(555) 234-5678"),
        Contact(name: "Carol White", phone: "(555) 345-6789"),
        Contact(name: "David Kim", phone: "(555) 456-7890"),
        Contact(name: "Eva Patel", phone: "(555) 567-8901"),
        Contact(name: "Frank Lee", phone: "(555) 678-9012"),
        Contact(name: "Grace Chen", phone: "(555) 789-0123"),
        Contact(name: "Henry Brown", phone: "(555) 890-1234"),
    ]

    var searchText = ""

    var filtered: [Contact] {
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Avatar

struct AvatarView: View {
    let initials: String
    let color: Color
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle()
                .fill(color.gradient)
                .frame(width: size, height: size)
            Text(initials)
                .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Row

struct ContactRowView: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(initials: contact.initials, color: contact.avatarColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(contact.name)
                    .font(.body)
                    .fontWeight(.medium)
                Text(contact.phone)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail

struct ContactDetailView: View {
    let contact: Contact

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                AvatarView(initials: contact.initials, color: contact.avatarColor, size: 100)
                    .padding(.top, 32)

                Text(contact.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(spacing: 0) {
                    infoRow(label: "Phone", value: contact.phone, icon: "phone.fill")
                }
                .background(.secondarySystemGroupedBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                Spacer()
            }
        }
        .background(.systemGroupedBackground)
        .navigationTitle(contact.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(contact.avatarColor)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - List

struct ContactListView: View {
    @State private var store = ContactStore()

    var body: some View {
        NavigationStack {
            List {
                if store.filtered.isEmpty {
                    ContentUnavailableView.search(text: store.searchText)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(store.filtered) { contact in
                        NavigationLink(destination: ContactDetailView(contact: contact)) {
                            ContactRowView(contact: contact)
                        }
                    }
                }
            }
            .navigationTitle("Contacts")
            .searchable(text: $store.searchText, prompt: "Search by name")
        }
    }
}

// MARK: - Preview

#Preview {
    ContactListView()
}
```

**Key design decisions:**

- `@Observable` on both `Contact` and `ContactStore` — no `@Published` boilerplate, direct property access in views
- `ContactStore.filtered` is a computed property, so the list reactively updates as `searchText` changes
- Avatar color is derived deterministically from `name.hashValue` so it's stable across re-renders without storing it
- `ContentUnavailableView.search` is the native iOS 17 empty-state for search (no custom view needed)
- `ContactDetailView` receives the `Contact` directly; since `Contact` is `@Observable`, any future edits would propagate automatically
