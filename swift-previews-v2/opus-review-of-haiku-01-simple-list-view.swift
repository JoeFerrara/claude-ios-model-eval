import SwiftUI
import Observation

// MARK: - Models

struct Contact: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let phoneNumber: String

    var initials: String {
        name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map { String($0).uppercased() } }
            .joined()
    }
}

// MARK: - View Model

@Observable
final class ContactListViewModel {
    var contacts: [Contact] = [
        Contact(name: "Alice Johnson", phoneNumber: "+1 (555) 123-4567"),
        Contact(name: "Bob Smith", phoneNumber: "+1 (555) 234-5678"),
        Contact(name: "Charlie Brown", phoneNumber: "+1 (555) 345-6789"),
        Contact(name: "Diana Prince", phoneNumber: "+1 (555) 456-7890"),
        Contact(name: "Eve Wilson", phoneNumber: "+1 (555) 567-8901"),
        Contact(name: "Frank Miller", phoneNumber: "+1 (555) 678-9012"),
        Contact(name: "Grace Lee", phoneNumber: "+1 (555) 789-0123"),
        Contact(name: "Henry Davis", phoneNumber: "+1 (555) 890-1234"),
    ]

    var searchText = ""

    var filteredContacts: [Contact] {
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let initials: String
    let size: CGFloat
    var backgroundColor: Color = .blue.opacity(0.7)

    var body: some View {
        Circle()
            .fill(backgroundColor)
            .frame(width: size, height: size)
            .overlay {
                Text(initials)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

// MARK: - Contact Row View

struct ContactRowView: View {
    let contact: Contact

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(initials: contact.initials, size: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.headline)

                Text(contact.phoneNumber)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Contact Detail View

struct ContactDetailView: View {
    let contact: Contact

    var body: some View {
        VStack(spacing: 24) {
            AvatarView(initials: contact.initials, size: 100)
                .padding(.top, 32)

            VStack(alignment: .leading, spacing: 16) {
                LabeledField(label: "Name", value: contact.name)

                LabeledField(label: "Phone Number", value: contact.phoneNumber)
                    .foregroundStyle(.blue)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)

            Spacer()
        }
        .navigationTitle("Contact Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LabeledField: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.semibold))
        }
    }
}

// MARK: - Contact List View

struct ContactListView: View {
    @State private var viewModel = ContactListViewModel()

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.filteredContacts) { contact in
                    NavigationLink(value: contact) {
                        ContactRowView(contact: contact)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
            }
            .listStyle(.plain)
            .navigationDestination(for: Contact.self) { contact in
                ContactDetailView(contact: contact)
            }
            .overlay {
                if viewModel.filteredContacts.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchText)
                }
            }
            .searchable(text: $viewModel.searchText, prompt: "Search contacts")
            .navigationTitle("Contacts")
        }
    }
}

// MARK: - App Entry Point

@main
struct ContactListApp: App {
    var body: some Scene {
        WindowGroup {
            ContactListView()
        }
    }
}

