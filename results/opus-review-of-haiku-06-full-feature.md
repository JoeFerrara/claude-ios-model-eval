```swift
import SwiftUI
import PhotosUI

// MARK: - Models

struct PasswordValidation {
    static func validate(_ password: String) -> String? {
        if password.count < 8 { return "Password must be at least 8 characters" }
        if !password.contains(where: \.isUppercase) { return "Must contain at least 1 uppercase letter" }
        if !password.contains(where: \.isNumber) { return "Must contain at least 1 number" }
        return nil
    }
}

struct StorageInfo {
    let usedBytes: Int64
    let totalBytes: Int64

    var percentUsed: Double {
        totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0
    }

    var formattedUsage: String {
        "\(usedBytes.formatted(.byteCount(style: .file))) / \(totalBytes.formatted(.byteCount(style: .file)))"
    }

    static func current() -> StorageInfo {
        do {
            let values = try URL.documentsDirectory.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = values.volumeAvailableCapacityForImportantUsage ?? 0
            return StorageInfo(usedBytes: max(0, total - available), totalBytes: max(total, 1))
        } catch {
            return StorageInfo(usedBytes: 0, totalBytes: 1)
        }
    }
}

// MARK: - View Models

@Observable
final class SettingsViewModel {
    var userName: String {
        didSet { UserDefaults.standard.set(userName, forKey: "userName") }
    }
    var userEmail: String {
        didSet { UserDefaults.standard.set(userEmail, forKey: "userEmail") }
    }
    var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }
    var darkModeEnabled: Bool {
        didSet { UserDefaults.standard.set(darkModeEnabled, forKey: "darkModeEnabled") }
    }
    var preferredLanguage: String {
        didSet { UserDefaults.standard.set(preferredLanguage, forKey: "preferredLanguage") }
    }

    var storageInfo = StorageInfo.current()
    var showSignOutAlert = false
    var showDeleteAccountAlert = false
    var showDeleteConfirmationAlert = false

    init() {
        let defaults = UserDefaults.standard
        userName = defaults.string(forKey: "userName") ?? ""
        userEmail = defaults.string(forKey: "userEmail") ?? ""
        notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        darkModeEnabled = defaults.bool(forKey: "darkModeEnabled")
        preferredLanguage = defaults.string(forKey: "preferredLanguage") ?? "en"
    }

    func refreshStorage() {
        storageInfo = .current()
    }

    func clearCache() {
        guard let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let contents = try? FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
        else { return }
        for url in contents {
            try? FileManager.default.removeItem(at: url)
        }
        refreshStorage()
    }

    func signOut() {
        userName = ""
        userEmail = ""
    }

    func deleteAccount() {
        userName = ""
        userEmail = ""
        notificationsEnabled = true
        darkModeEnabled = false
        preferredLanguage = "en"
    }
}

@Observable
final class PasswordChangeViewModel {
    var oldPassword = ""
    var newPassword = ""
    var confirmPassword = ""
    var showPassword = false
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?

    var newPasswordError: String? {
        newPassword.isEmpty ? nil : PasswordValidation.validate(newPassword)
    }

    var confirmPasswordError: String? {
        guard !confirmPassword.isEmpty, !newPassword.isEmpty else { return nil }
        return confirmPassword == newPassword ? nil : "Passwords do not match"
    }

    var isFormValid: Bool {
        !oldPassword.isEmpty &&
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPasswordError == nil &&
        confirmPasswordError == nil
    }

    func changePassword() async {
        isLoading = true
        defer { isLoading = false }

        // Simulate API call
        try? await Task.sleep(for: .seconds(1))

        errorMessage = nil
        successMessage = "Password changed successfully"
        oldPassword = ""
        newPassword = ""
        confirmPassword = ""
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        NavigationStack {
            List {
                ProfileSection(viewModel: viewModel)
                PreferencesSection(viewModel: viewModel)
                StorageSection(viewModel: viewModel)
                AccountSection(viewModel: viewModel)
            }
            .navigationTitle("Settings")
            .preferredColorScheme(viewModel.darkModeEnabled ? .dark : nil)
        }
    }
}

// MARK: - Profile Section

struct ProfileSection: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var profileImage: Image?
    @State private var nameError: String?
    @State private var emailError: String?

    var body: some View {
        Section("Profile") {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                if let profileImage {
                    profileImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundStyle(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .onChange(of: selectedItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        profileImage = Image(uiImage: uiImage)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                TextField("Name", text: $viewModel.userName)
                    .textContentType(.name)
                    .submitLabel(.next)
                    .onChange(of: viewModel.userName) { _, value in
                        nameError = value.trimmingCharacters(in: .whitespaces).isEmpty ? "Name is required" : nil
                    }
                if let nameError {
                    Text(nameError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                TextField("Email", text: $viewModel.userEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onChange(of: viewModel.userEmail) { _, value in
                        if value.isEmpty {
                            emailError = nil
                        } else {
                            let pattern = /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/
                            emailError = value.wholeMatch(of: pattern) != nil ? nil : "Invalid email format"
                        }
                    }
                if let emailError {
                    Text(emailError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Preferences Section

struct PreferencesSection: View {
    @Bindable var viewModel: SettingsViewModel

    private let languages: [(code: String, name: String)] = [
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("ja", "Japanese")
    ]

    var body: some View {
        Section("Preferences") {
            Toggle("Notifications", isOn: $viewModel.notificationsEnabled)
            Toggle("Dark Mode", isOn: $viewModel.darkModeEnabled)
            Picker("Language", selection: $viewModel.preferredLanguage) {
                ForEach(languages, id: \.code) { language in
                    Text(language.name).tag(language.code)
                }
            }
        }
    }
}

// MARK: - Storage Section

struct StorageSection: View {
    var viewModel: SettingsViewModel
    @State private var showClearCacheAlert = false

    var body: some View {
        Section("Storage") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Space Used")
                    Spacer()
                    Text(viewModel.storageInfo.formattedUsage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: viewModel.storageInfo.percentUsed)
                    .tint(storageColor)
            }
            .padding(.vertical, 4)

            Button("Clear Cache", systemImage: "trash", role: .destructive) {
                showClearCacheAlert = true
            }
            .alert("Clear Cache", isPresented: $showClearCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) { viewModel.clearCache() }
            } message: {
                Text("This will free up space by removing cached data. This action cannot be undone.")
            }
        }
    }

    private var storageColor: Color {
        switch viewModel.storageInfo.percentUsed {
        case 0.9...: .red
        case 0.75...: .orange
        default: .green
        }
    }
}

// MARK: - Account Section

struct AccountSection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Section("Account") {
            NavigationLink {
                PasswordChangeView()
            } label: {
                Label("Change Password", systemImage: "key.fill")
            }

            Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                viewModel.showSignOutAlert = true
            }

            Button("Delete Account", systemImage: "trash.fill", role: .destructive) {
                viewModel.showDeleteAccountAlert = true
            }
        }
        .alert("Sign Out", isPresented: $viewModel.showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) { viewModel.signOut() }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $viewModel.showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { viewModel.showDeleteConfirmationAlert = true }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .alert("Final Confirmation", isPresented: $viewModel.showDeleteConfirmationAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) { viewModel.deleteAccount() }
        } message: {
            Text("Are you sure you want to permanently delete your account?")
        }
    }
}

// MARK: - Password Change View

struct PasswordChangeView: View {
    @State private var viewModel = PasswordChangeViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case oldPassword, newPassword, confirmPassword
    }

    var body: some View {
        Form {
            Section("Change Your Password") {
                passwordField("Old Password", text: $viewModel.oldPassword, contentType: .password, field: .oldPassword, nextField: .newPassword, error: nil)
                passwordField("New Password", text: $viewModel.newPassword, contentType: .newPassword, field: .newPassword, nextField: .confirmPassword, error: viewModel.newPasswordError)
                passwordField("Confirm Password", text: $viewModel.confirmPassword, contentType: .password, field: .confirmPassword, nextField: nil, error: viewModel.confirmPasswordError)
            }

            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundStyle(.red) }
            }

            if let success = viewModel.successMessage {
                Section { Text(success).foregroundStyle(.green) }
            }

            Section {
                Button {
                    Task {
                        await viewModel.changePassword()
                        try? await Task.sleep(for: .seconds(1))
                        dismiss()
                    }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Change Password")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(!viewModel.isFormValid || viewModel.isLoading)
            }
        }
        .navigationTitle("Change Password")
        .onSubmit {
            switch focusedField {
            case .oldPassword: focusedField = .newPassword
            case .newPassword: focusedField = .confirmPassword
            case .confirmPassword, nil: focusedField = nil
            }
        }
    }

    @ViewBuilder
    private func passwordField(
        _ title: String,
        text: Binding<String>,
        contentType: UITextContentType,
        field: Field,
        nextField: Field?,
        error: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Group {
                    if viewModel.showPassword {
                        TextField(title, text: text)
                    } else {
                        SecureField(title, text: text)
                    }
                }
                .textContentType(contentType)
                .focused($focusedField, equals: field)
                .submitLabel(nextField != nil ? .next : .done)

                if field == .oldPassword {
                    Button {
                        viewModel.showPassword.toggle()
                    } label: {
                        Image(systemName: viewModel.showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
```

**Changes made:**

- **Replaced `UIImagePickerController` wrapper** with native `PhotosPicker` from PhotosUI — eliminated ~60 lines of UIKit bridging code and the fake `.photosPicker` View extension
- **Fixed `@AppStorage` inside `@Observable`** — `@AppStorage` doesn't work in `@Observable` classes; replaced with `UserDefaults` get/set via `init`/`didSet`
- **Replaced `NSSearchPathForDirectoriesInDomains`** with `URL.documentsDirectory` and `URLResourceValues` for storage info
- **Replaced `NSPredicate` email validation** with Swift `Regex` literal
- **Replaced deprecated APIs**: `.autocapitalization(.none)` → `.textInputAutocapitalization(.never)`, `.foregroundColor` → `.foregroundStyle`
- **Replaced `String(format:)` byte formatting** with `.formatted(.byteCount(style:))`
- **Replaced `Task.sleep(nanoseconds:)`** with `Task.sleep(for: .seconds(1))`
- **Fixed `isFormValid`** — was missing checks for `newPassword` and `confirmPassword` being non-empty
- **Removed dead code**: `ValidationError` (unused), `oldPasswordError` (always `nil`), `EmailValidator` struct (inlined), `usedGB`/`totalGB` (replaced by `formattedUsage`)
- **Fixed `clearCache`** — was deleting the caches directory itself; now deletes only its contents
- **Extracted `passwordField` helper** to eliminate the 3× copy-pasted `if showPassword { TextField } else { SecureField }` blocks
- **Moved alerts to Section level** in `AccountSection` instead of chaining on individual buttons
- **Added `private` access control** where appropriate, marked classes `final`
- **Used switch expression** for `storageColor`, modern `Button` initializers with `systemImage` parameter
