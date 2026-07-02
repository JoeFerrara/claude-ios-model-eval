```swift
import SwiftUI
import PhotosUI

// MARK: - App Entry Point

@main
struct SettingsApp: App {
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SettingsView()
            }
            .preferredColorScheme(isDarkMode ? .dark : .light)
        }
    }
}

// MARK: - Models

@Observable
final class SettingsViewModel {
    var userProfile = UserProfile.load()

    func saveProfile() {
        userProfile.save()
    }
}

struct UserProfile: Codable {
    var name = ""
    var email = ""
    var profileImageData: Data?

    private static let key = "userProfile"

    static func load() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: key),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return UserProfile()
        }
        return profile
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

// MARK: - Validation

enum Validation {
    static func isValidEmail(_ email: String) -> Bool {
        email.wholeMatch(of: /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/) != nil
    }

    static func passwordErrors(_ password: String) -> [String] {
        var errors: [String] = []
        if password.count < 8 { errors.append("At least 8 characters") }
        if !password.contains(where: \.isUppercase) { errors.append("1 uppercase letter") }
        if !password.contains(where: \.isNumber) { errors.append("1 number") }
        return errors
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let userSignedOut = Notification.Name("userSignedOut")
    static let accountDeleted = Notification.Name("accountDeleted")
}

// MARK: - Settings View

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("preferredLanguage") private var preferredLanguage = "English"

    var body: some View {
        List {
            profileSection
            preferencesSection
            storageSection
            accountSection
        }
        .navigationTitle("Settings")
        .listStyle(.insetGrouped)
    }

    private var profileSection: some View {
        Section("Profile") {
            VStack(spacing: 16) {
                ProfilePhotoPicker(imageData: $viewModel.userProfile.profileImageData)
                    .onChange(of: viewModel.userProfile.profileImageData) {
                        viewModel.saveProfile()
                    }

                VStack(spacing: 12) {
                    TextField("Full Name", text: $viewModel.userProfile.name)
                        .textContentType(.name)
                        .onChange(of: viewModel.userProfile.name) {
                            viewModel.saveProfile()
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Email", text: $viewModel.userProfile.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: viewModel.userProfile.email) {
                                viewModel.saveProfile()
                            }

                        if !viewModel.userProfile.email.isEmpty,
                           !Validation.isValidEmail(viewModel.userProfile.email) {
                            Label("Invalid email format", systemImage: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var preferencesSection: some View {
        Section("Preferences") {
            Toggle("Notifications", isOn: $notificationsEnabled)
            Toggle("Dark Mode", isOn: $isDarkMode)

            Picker("Language", selection: $preferredLanguage) {
                ForEach(["English", "Spanish", "French", "German", "Chinese"], id: \.self) {
                    Text($0)
                }
            }
        }
    }

    private var storageSection: some View {
        Section("Storage") {
            StorageView()
        }
    }

    private var accountSection: some View {
        Section("Account") {
            NavigationLink("Change Password") {
                ChangePasswordView()
            }
            SignOutButton()
            DeleteAccountButton()
        }
    }
}

// MARK: - Profile Photo Picker

struct ProfilePhotoPicker: View {
    @Binding var imageData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var cameraImage: UIImage?

    var body: some View {
        VStack {
            Menu {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Label("Photo Library", systemImage: "photo.stack")
                }
                Button {
                    showCamera = true
                } label: {
                    Label("Camera", systemImage: "camera")
                }
            } label: {
                profileImage
            }
            .onChange(of: selectedItem) {
                Task {
                    if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPicker(image: $cameraImage)
            }
            .onChange(of: cameraImage) {
                if let image = cameraImage {
                    imageData = image.jpegData(compressionQuality: 0.8)
                }
            }

            Text("Tap to change photo")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var profileImage: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.gray)
                    )
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(Circle())
        .overlay(Circle().stroke(.blue, lineWidth: 2))
    }
}

// MARK: - Camera Picker

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Storage View

struct StorageView: View {
    @State private var usedSpace: Int64 = 0
    @State private var totalSpace: Int64 = 0
    @State private var showClearCacheAlert = false

    private var usedFraction: Double {
        totalSpace > 0 ? Double(usedSpace) / Double(totalSpace) : 0
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Storage Used")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(formatted(usedSpace)) / \(formatted(totalSpace))")
                        .font(.headline)
                }
                Spacer()
            }

            ProgressView(value: usedFraction)
                .tint(.blue)

            Button(role: .destructive) {
                showClearCacheAlert = true
            } label: {
                Label("Clear Cache", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .alert("Clear Cache?", isPresented: $showClearCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { clearCache() }
            } message: {
                Text("This will clear cached data but won't delete your personal files.")
            }
        }
        .padding(.vertical, 8)
        .onAppear { calculateStorage() }
    }

    private func calculateStorage() {
        let fm = FileManager.default
        if let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            usedSpace = directorySize(at: docsURL)
        }
        if let attrs = try? fm.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let space = attrs[.systemSize] as? Int64 {
            totalSpace = space
        }
    }

    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        var size: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize {
                size += Int64(fileSize)
            }
        }
        return size
    }

    private func clearCache() {
        let fm = FileManager.default
        guard let cachesURL = fm.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let files = try? fm.contentsOfDirectory(at: cachesURL, includingPropertiesForKeys: nil) else {
            return
        }
        for file in files {
            try? fm.removeItem(at: file)
        }
        calculateStorage()
    }

    private func formatted(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

// MARK: - Change Password View

struct ChangePasswordView: View {
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var showOldPassword = false
    @State private var showNewPassword = false
    @State private var showConfirmPassword = false
    @State private var showSuccess = false
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field { case old, new, confirm }

    private var isFormValid: Bool {
        !oldPassword.isEmpty &&
        Validation.passwordErrors(newPassword).isEmpty &&
        confirmPassword == newPassword
    }

    var body: some View {
        Form {
            Section("Current Password") {
                passwordField($oldPassword, visible: showOldPassword) { showOldPassword.toggle() }
                    .focused($focusedField, equals: .old)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .new }
            }

            Section("New Password") {
                passwordField($newPassword, visible: showNewPassword) { showNewPassword.toggle() }
                    .focused($focusedField, equals: .new)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .confirm }

                if !newPassword.isEmpty {
                    let errors = Validation.passwordErrors(newPassword)
                    if errors.isEmpty {
                        Label("Password is valid", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Password must have:")
                                .font(.caption)
                                .foregroundStyle(.red)
                            ForEach(errors, id: \.self) { error in
                                Label(error, systemImage: "circle")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }

            Section("Confirm Password") {
                passwordField($confirmPassword, visible: showConfirmPassword) { showConfirmPassword.toggle() }
                    .focused($focusedField, equals: .confirm)
                    .submitLabel(.done)

                if !confirmPassword.isEmpty {
                    if confirmPassword == newPassword {
                        Label("Passwords match", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Passwords don't match", systemImage: "exclamationmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section {
                Button {
                    showSuccess = true
                } label: {
                    Text("Change Password")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.white)
                }
                .listRowBackground(isFormValid ? Color.blue : Color.gray.opacity(0.5))
                .disabled(!isFormValid)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Password Changed", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your password has been successfully updated.")
        }
    }

    private func passwordField(_ text: Binding<String>, visible: Bool, toggle: @escaping () -> Void) -> some View {
        HStack {
            Group {
                if visible {
                    TextField("Password", text: text)
                } else {
                    SecureField("Password", text: text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            Button(action: toggle) {
                Image(systemName: visible ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Sign Out Button

struct SignOutButton: View {
    @State private var showConfirmation = false

    var body: some View {
        Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
            showConfirmation = true
        }
        .alert("Sign Out?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                UserDefaults.standard.set(false, forKey: "isLoggedIn")
                NotificationCenter.default.post(name: .userSignedOut, object: nil)
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

// MARK: - Delete Account Button

struct DeleteAccountButton: View {
    @State private var showFirstConfirmation = false
    @State private var showSecondConfirmation = false

    var body: some View {
        Button("Delete Account", systemImage: "exclamationmark.triangle", role: .destructive) {
            showFirstConfirmation = true
        }
        .alert("Delete Account?", isPresented: $showFirstConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                showSecondConfirmation = true
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .alert("Confirm Deletion", isPresented: $showSecondConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Account", role: .destructive) {
                UserDefaults.standard.removeObject(forKey: "userProfile")
                UserDefaults.standard.set(false, forKey: "isLoggedIn")
                NotificationCenter.default.post(name: .accountDeleted, object: nil)
            }
        } message: {
            Text("Are you absolutely sure?")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
```

Key changes made:

- **Eliminated `ContentView` wrapper** — `SettingsApp` owns the `NavigationStack` directly
- **Replaced `NotificationCenter` dark mode bridge with `@AppStorage`** — both `SettingsApp` and `SettingsView` observe the same key reactively
- **Replaced inline `Binding(get:set:)` to UserDefaults with `@AppStorage`** properties
- **Fixed `.menu` modifier (doesn't exist)** — replaced with `Menu { } label: { }` view
- **Replaced `NSPredicate` email validation** with Swift `Regex` (`wholeMatch(of:)`)
- **Changed `ValidationRules` struct to `enum`** — caseless enum is idiomatic for Swift namespaces
- **Removed `isValidPassword`** — redundant with `passwordErrors(_:).isEmpty`
- **Replaced all `.foregroundColor` with `.foregroundStyle`** (modern API)
- **Used `Label` instead of manual `HStack { Image; Text }`** throughout
- **Removed duplicate chevron** inside `NavigationLink` (list provides one automatically)
- **Removed unused `@Environment(\.dismiss)`** from `SignOutButton` and `DeleteAccountButton`
- **Removed unused `selectedTab`** from `SettingsView`
- **Moved `onChange(of: cameraImage)` out of `.sheet`** content to sibling modifier
- **Extracted `passwordField` helper** to deduplicate three identical password row layouts
- **Used `resourceValues(forKeys:)`** instead of `attributesOfItem(atPath:)` for file sizes
- **Used `ByteCountFormatter.string(fromByteCount:countStyle:)` class method** instead of instance
- **Removed password storage in UserDefaults** — storing plaintext passwords locally is a security vulnerability
- **Fixed misleading "Type your email to confirm" text** in delete confirmation (no text field existed)
- **Added `.textInputAutocapitalization(.never)`** to email and password fields
- **Added `.buttonStyle(.plain)`** to password visibility toggles to prevent row highlight
- **Used typed `Notification.Name` extensions** instead of raw string literals
- **Renamed types** to drop `View` suffix where redundant (`StorageSectionView` → `StorageView`, etc.)
