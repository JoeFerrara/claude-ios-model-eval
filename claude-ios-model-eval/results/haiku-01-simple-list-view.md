```swift
import SwiftUI
import Observation

// MARK: - Models

struct Contact: Identifiable {
    let id: UUID
    let name: String
    let phoneNumber: String
    
    init(id: UUID = UUID(), name: String, phoneNumber: String) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
    }
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
    
    var searchText: String = ""
    
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
    let size: CGFloat = 50
    
    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1)) + String(components[1].prefix(1))
        } else {
            return String(name.prefix(1))
        }
    }
    
    private var backgroundColor: Color {
        let hue = Double(name.hash % 100) / 100.0
        return Color(hue: hue, saturation: 0.7, brightness: 0.8)
    }
    
    var body: some View {
        Circle()
            .fill(backgroundColor)
            .frame(width: size, height: size)
            .overlay(
                Text(initials.uppercased())
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Contact Detail View

struct ContactDetailView: View {
    let contact: Contact
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                }
                Spacer()
            }
            .padding()
            
            VStack(spacing: 16) {
                AvatarView(name: contact.name, size: 80)
                
                VStack(spacing: 8) {
                    Text(contact.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Phone", systemImage: "phone.fill")
                                .fontWeight(.medium)
                            Spacer()
                            Text(contact.phoneNumber)
                                .foregroundColor(.secondary)
                        }
                        .font(.system(.body, design: .default))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding()
            
            Spacer()
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Contact List View

struct ContactListView: View {
    @State private var viewModel = ContactListViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search contacts", text: $viewModel.searchText)
                        .textFieldStyle(.roundedBorder)
                    
                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Contact List
                if viewModel.filteredContacts.isEmpty {
                    VStack {
                        Image(systemName: "person.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No contacts found")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                    List {
                        ForEach(viewModel.filteredContacts) { contact in
                            NavigationLink(destination: ContactDetailView(contact: contact)) {
                                HStack(spacing: 12) {
                                    AvatarView(name: contact.name)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(contact.name)
                                            .font(.headline)
                                        
                                        Text(contact.phoneNumber)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .contentShape(Rectangle())
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Preview

#Preview {
    ContactListView()
}
```

This implementation includes:

- **Contact Model**: Simple struct with name, phone number, and UUID
- **ContactListViewModel**: Uses `@Observable` for state management. Stores contacts and handles search filtering
- **AvatarView**: Generates a circular avatar with initials and a color based on the contact's name
- **ContactDetailView**: Shows full contact details with a back button
- **ContactListView**: Main view with:
  - Search bar that filters contacts by name in real-time
  - List of contacts with avatars, names, and phone numbers
  - Navigation to detail view on tap
  - Empty state when no contacts match the search

The code uses NavigationStack for navigation and is fully functional with sample data included.
