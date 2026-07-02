Here's the complete Settings screen implementation:

---

### `SettingsApp.swift`

```swift
import SwiftUI

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
```

---

### `Validation.swift`

```swift
import Foundation

enum Validation {
    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    static func isValidPassword(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        return hasUppercase && hasNumber
    }

    static func passwordErrors(_ password: String) -> [String] {
        var errors: [String] = []
        if password.count < 8 { errors.append("Must be at least 8 characters") }
        if password.range(of: "[A-Z]", options: .regularExpression) == nil {
            errors.append("Must contain at least 1 uppercase letter")
        }
        if password.range(of: "[0-9]", options: .regularExpression) == nil {
            errors.append("Must contain at least 1 number")
        }
        return errors
    }
}
```

---

### `SettingsViewModel.swift`

```swift
import SwiftUI
import PhotosUI
import Observation

@Observable
final class SettingsViewModel {
    // MARK: - Profile
    var profileImage: UIImage?
    var selectedPhotoItem: PhotosPickerItem? {
        didSet { loadPhoto() }
    }
    var name: String {
        didSet { UserDefaults.standard.set(name, forKey: "userName") }
    }
    var email: String {
        didSet { UserDefaults.standard.set(email, forKey: "userEmail") }
    }
    var emailTouched = false

    var emailError: String? {
        guard emailTouched, !email.isEmpty else { return nil }
        return Validation.isValidEmail(email) ? nil : "Enter a valid email address"
    }

    // MARK: - Storage
    var usedStorageMB: Double = 0
    let totalStorageMB: Double = 500
    var storageProgress: Double { min(usedStorageMB / totalStorageMB, 1.0) }
    var showClearCacheAlert = false
    var cacheCleared = false

    // MARK: - Account
    var showSignOutAlert = false
    var showDeleteFirstAlert = false
    var showDeleteConfirmAlert = false

    init() {
        self.name = UserDefaults.standard.string(forKey: "userName") ?? ""
        self.email = UserDefaults.standard.string(forKey: "userEmail") ?? ""
        if let data = UserDefaults.standard.data(forKey: "profileImageData"),
           let image = UIImage(data: data) {
            self.profileImage = image
        }
        calculateStorage()
    }

    private func loadPhoto() {
        guard let item = selectedPhotoItem else { return }
        Task { @MainActor in
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                self.profileImage = image
                UserDefaults.standard.set(image.jpegData(compressionQuality: 0.8), forKey: "profileImageData")
            }
        }
    }

    func calculateStorage() {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        let tmpURL = FileManager.default.temporaryDirectory
        var totalBytes: Int64 = 0
        for url in [cacheURL, tmpURL].compactMap({ $0 }) {
            if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
                    totalBytes += Int64(size)
                }
            }
        }
        usedStorageMB = Double(totalBytes) / 1_048_576
    }

    func clearCache() {
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        if let cacheURL, let contents = try? FileManager.default.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil) {
            for file in contents {
                try? FileManager.default.removeItem(at: file)
            }
        }
        calculateStorage()
        cacheCleared = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            cacheCleared = false
        }
    }
}
```

---

### `ChangePasswordViewModel.swift`

```swift
import Observation

@Observable
final class ChangePasswordViewModel {
    var oldPassword = ""
    var newPassword = ""
    var confirmPassword = ""

    var oldTouched = false
    var newTouched = false
    var confirmTouched = false

    var showSuccess = false

    var oldPasswordError: String? {
        guard oldTouched, oldPassword.isEmpty else { return nil }
        return "Current password is required"
    }

    var newPasswordErrors: [String] {
        guard newTouched, !newPassword.isEmpty else { return [] }
        return Validation.passwordErrors(newPassword)
    }

    var confirmPasswordError: String? {
        guard confirmTouched, !confirmPassword.isEmpty else { return nil }
        return confirmPassword == newPassword ? nil : "Passwords do not match"
    }

    var isValid: Bool {
        !oldPassword.isEmpty
            && Validation.isValidPassword(newPassword)
            && confirmPassword == newPassword
    }

    func submit() {
        oldTouched = true
        newTouched = true
        confirmTouched = true
        guard isValid else { return }
        // In a real app, call an API here
        showSuccess = true
    }
}
```

---

### `SettingsView.swift`

```swift
import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            ProfileSection(viewModel: viewModel)
            PreferencesSection()
            StorageSection(viewModel: viewModel)
            AccountSection(viewModel: viewModel)
        }
        .navigationTitle("Settings")
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
```

---

### `ProfileSection.swift`

```swift
import SwiftUI
import PhotosUI

struct ProfileSection: View {
    @Bindable var viewModel: SettingsViewModel
    @FocusState private var focusedField: ProfileField?

    private enum ProfileField: Hashable {
        case name, email
    }

    var body: some View {
        Section("Profile") {
            HStack {
                Spacer()
                PhotosPicker(selection: $viewModel.selectedPhotoItem, matching: .images) {
                    if let image = viewModel.profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(cameraOverlay)
                    } else {
                        Circle()
                            .fill(.gray.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .overlay {
                                Image(systemName: "camera.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                Spacer()
            }
            .listRowBackground(Color.clear)

            TextField("Name", text: $viewModel.name)
                .textContentType(.name)
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit { focusedField = .email }

            VStack(alignment: .leading, spacing: 4) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .email)
                    .submitLabel(.done)
                    .onSubmit { focusedField = nil }
                    .onChange(of: viewModel.email) {
                        viewModel.emailTouched = true
                    }

                if let error = viewModel.emailError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var cameraOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(systemName: "camera.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .blue)
            }
        }
    }
}
```

---

### `PreferencesSection.swift`

```swift
import SwiftUI

struct PreferencesSection: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("preferredLanguage") private var preferredLanguage = "en"

    private let languages = [
        ("en", "English"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("ja", "Japanese"),
        ("zh", "Chinese"),
        ("ko", "Korean"),
        ("pt", "Portuguese"),
    ]

    var body: some View {
        Section("Preferences") {
            Toggle("Notifications", systemImage: "bell.fill", isOn: $notificationsEnabled)

            Toggle("Dark Mode", systemImage: "moon.fill", isOn: $isDarkMode)

            Picker(selection: $preferredLanguage) {
                ForEach(languages, id: \.0) { code, name in
                    Text(name).tag(code)
                }
            } label: {
                Label("Language", systemImage: "globe")
            }
        }
    }
}
```

---

### `StorageSection.swift`

```swift
import SwiftUI

struct StorageSection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Section("Storage") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Used")
                    Spacer()
                    Text(String(format: "%.1f MB / %.0f MB", viewModel.usedStorageMB, viewModel.totalStorageMB))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: viewModel.storageProgress)
                    .tint(progressColor)
            }
            .padding(.vertical, 4)

            Button(role: .destructive) {
                viewModel.showClearCacheAlert = true
            } label: {
                HStack {
                    Label("Clear Cache", systemImage: "trash")
                    Spacer()
                    if viewModel.cacheCleared {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .alert("Clear Cache", isPresented: $viewModel.showClearCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    withAnimation { viewModel.clearCache() }
                }
            } message: {
                Text("This will remove all cached data. This action cannot be undone.")
            }
        }
    }

    private var progressColor: Color {
        switch viewModel.storageProgress {
        case ..<0.6: .blue
        case ..<0.85: .orange
        default: .red
        }
    }
}
```

---

### `AccountSection.swift`

```swift
import SwiftUI

struct AccountSection: View {
    @Bindable var viewModel: SettingsViewModel

    var body: some View {
        Section("Account") {
            NavigationLink {
                ChangePasswordView()
            } label: {
                Label("Change Password", systemImage: "lock.fill")
            }

            Button(role: .destructive) {
                viewModel.showSignOutAlert = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .alert("Sign Out", isPresented: $viewModel.showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Sign Out", role: .destructive) {
                    // Handle sign out
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }

            Button(role: .destructive) {
                viewModel.showDeleteFirstAlert = true
            } label: {
                Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                    .foregroundStyle(.red)
            }
            .alert("Delete Account", isPresented: $viewModel.showDeleteFirstAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    viewModel.showDeleteConfirmAlert = true
                }
            } message: {
                Text("This will permanently delete your account and all associated data.")
            }
            .alert("Are you absolutely sure?", isPresented: $viewModel.showDeleteConfirmAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Permanently Delete", role: .destructive) {
                    // Handle account deletion
                }
            } message: {
                Text("This action CANNOT be undone. All your data will be permanently removed.")
            }
        }
    }
}
```

---

### `ChangePasswordView.swift`

```swift
import SwiftUI

struct ChangePasswordView: View {
    @State private var viewModel = ChangePasswordViewModel()
    @FocusState private var focusedField: Field?
    @Environment(\.dismiss) private var dismiss

    private enum Field: Hashable {
        case old, new, confirm
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    SecureField("Current Password", text: $viewModel.oldPassword)
                        .textContentType(.password)
                        .focused($focusedField, equals: .old)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .new }
                        .onChange(of: viewModel.oldPassword) {
                            viewModel.oldTouched = true
                        }

                    if let error = viewModel.oldPasswordError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    SecureField("New Password", text: $viewModel.newPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .new)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .confirm }
                        .onChange(of: viewModel.newPassword) {
                            viewModel.newTouched = true
                        }

                    ForEach(viewModel.newPasswordErrors, id: \.self) { error in
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    SecureField("Confirm Password", text: $viewModel.confirmPassword)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirm)
                        .submitLabel(.done)
                        .onSubmit { submit() }
                        .onChange(of: viewModel.confirmPassword) {
                            viewModel.confirmTouched = true
                        }

                    if let error = viewModel.confirmPasswordError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            } footer: {
                Text("Password must be at least 8 characters with 1 uppercase letter and 1 number.")
            }

            Section {
                Button("Update Password") { submit() }
                    .frame(maxWidth: .infinity)
                    .disabled(!viewModel.isValid)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture {
            focusedField = nil
        }
        .alert("Password Updated", isPresented: $viewModel.showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your password has been changed successfully.")
        }
    }

    private func submit() {
        focusedField = nil
        viewModel.submit()
    }
}
```

---

### Key design decisions

- **`@Observable` macro** (iOS 17+) for both view models — no `@Published` boilerplate, fine-grained view updates.
- **`@AppStorage`** directly on `PreferencesSection` for toggles/picker and on the `App` struct for dark mode — these survive app restarts with zero extra code.
- **`@Bindable`** used when passing `@Observable` objects into child views that need two-way bindings.
- **`PhotosPicker`** from PhotosUI — no need for `UIImagePickerController` wrapping. The `loadTransferable` async call handles the photo → `UIImage` conversion.
- **Inline validation** uses computed properties on the view models that derive error messages from current field state + a `touched` flag so errors only appear after the user interacts.
- **Double-confirmation delete** chains two `.alert` modifiers — the destructive button on the first triggers the second.
- **Keyboard handling**: `@FocusState` with `.submitLabel` and `.onSubmit` chains fields together; `.scrollDismissesKeyboard(.interactively)` and a tap gesture dismiss on outside tap.
- **Storage calculation** enumerates the caches/tmp directories on disk for a real (if small) number.
