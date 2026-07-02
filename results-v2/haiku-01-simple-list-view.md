```swift
import SwiftUI
import Observation

// MARK: - Models

struct Contact: Identifiable {
    let id = UUID()
    let name: String
    let phoneNumber: String
    
    var initials: String {
        name
            .split(separator: " ")
            .prefix(2)
            .map { String($0.prefix(1)).uppercased() }
            .joined()
    }
}

// MARK: - View Models

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
    
    var searchText: String = ""
    
    var filteredContacts: [Contact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            contact.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Avatar View

struct AvatarView: View {
    let initials: String
    let backgroundColor: Color
    
    var body: some View {
        Circle()
            .fill(backgroundColor)
            .frame(width: 44, height: 44)
            .overlay(
                Text(initials)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            )
    }
}

// MARK: - Contact Row View

struct ContactRowView: View {
    let contact: Contact
    
    var body: some View {
        HStack(spacing: 12) {
            AvatarView(
                initials: contact.initials,
                backgroundColor: .blue.opacity(0.7)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(contact.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(contact.phoneNumber)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Contact Detail View

struct ContactDetailView: View {
    let contact: Contact
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            AvatarView(
                initials: contact.initials,
                backgroundColor: .blue.opacity(0.7)
            )
            .frame(width: 100, height: 100)
            .padding(.top, 32)
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(contact.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Phone Number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(contact.phoneNumber)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .navigationTitle("Contact Details")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

// MARK: - Contact List View

struct ContactListView: View {
    @State private var viewModel = ContactListViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SearchBar(text: $viewModel.searchText)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                
                if viewModel.filteredContacts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        
                        Text("No Contacts Found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        if !viewModel.searchText.isEmpty {
                            Text("Try a different search term")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 32)
                } else {
                    List {
                        ForEach(viewModel.filteredContacts) { contact in
                            NavigationLink(destination: ContactDetailView(contact: contact)) {
                                ContactRowView(contact: contact)
                            }
                            .listRowSeparator(.visible)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Contacts")
            .background(Color(.systemBackground))
        }
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search contacts", text: $text)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
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
```

**Key Features:**

- **@Observable**: `ContactListViewModel` uses the new Observable macro for iOS 17+ state management
- **Search Filtering**: SearchBar filters contacts by name in real-time
- **Navigation**: NavigationStack handles navigation from list to detail view
- **Avatar**: Circular avatar displays contact initials with color background
- **Empty State**: Shows appropriate message when no contacts match search
- **Single File**: All code compiles as one iOS app target with no external dependencies

The app includes sample contacts and is ready to run on iOS 17+.
