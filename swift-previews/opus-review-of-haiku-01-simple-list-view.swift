import SwiftUI
import Observation

// MARK: - Models

struct Contact: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let phoneNumber: String
}

// MARK: - View Model

@Observable
final class ContactListViewModel {
    var contacts: [Contact] = [
        Contact(name: "Alice Johnson", phoneNumber: "(555) 123-4567"),
        Contact(name: "Bob Smith", phoneNumber: "(555) 234-5678"),
        Contact(name: "Carol White", phoneNumber: "(555) 345-6789"),
        Contact(name: "David Brown", phoneNumber: "(555) 456-7890"),
        Contact(name: "Eve Davis", phoneNumber: "(555) 567-8901"),
    ]

    var searchText = ""

    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let name: String
    var size: CGFloat = 50

    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        }
        return String(name.prefix(1))
    }

    private var backgroundColor: Color {
        let hue = Double(abs(name.hashValue) % 100) / 100.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }

    var body: some View {
        Circle()
            .fill(backgroundColor)
            .frame(width: size, height: size)
            .overlay {
                Text(initials.uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

// MARK: - Contact Detail View

struct ContactDetailView: View {
    let contact: Contact

    var body: some View {
        VStack(spacing: 16) {
            AvatarView(name: contact.name, size: 80)

            Text(contact.name)
                .font(.title2.weight(.semibold))

            HStack {
                Label("Phone", systemImage: "phone.fill")
                    .fontWeight(.medium)
                Spacer()
                Text(contact.phoneNumber)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.quaternary, in: .rect(cornerRadius: 8))

            Spacer()
        }
        .padding()
        .navigationTitle(contact.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Contact List View

struct ContactListView: View {
    @State private var viewModel = ContactListViewModel()

    var body: some View {
        NavigationStack {
            List(viewModel.filteredContacts) { contact in
                NavigationLink(value: contact) {
                    HStack(spacing: 12) {
                        AvatarView(name: contact.name)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(contact.name)
                                .font(.headline)
                            Text(contact.phoneNumber)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Contacts")
            .navigationDestination(for: Contact.self) { contact in
                ContactDetailView(contact: contact)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search contacts")
            .overlay {
                if viewModel.filteredContacts.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContactListView()
}

