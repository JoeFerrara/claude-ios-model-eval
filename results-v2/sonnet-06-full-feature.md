Here are all the files:

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

### `Validators.swift`
```swift
import Foundation

enum Validators {
    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    /// 8+ chars, ≥1 uppercase, ≥1 digit
    static func isValidPassword(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }
        let hasUpper = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasDigit = password.range(of: "[0-9]", options: .regularExpression) != nil
        return hasUpper && hasDigit
    }
}
```

---

### `SettingsViewModel.swift`
```swift
import SwiftUI
import Observation
import PhotosUI

@Observable
final class SettingsViewModel {

    // MARK: Profile
    var name: String {
        didSet { UserDefaults.standard.set(name, forKey: Keys.name) }
    }
    var email: String {
        didSet { UserDefaults.standard.set(email, forKey: Keys.email) }
    }
    var profileImageData: Data? {
        didSet { UserDefaults.standard.set(profileImageData, forKey: Keys.photo) }
    }
    var emailError: String? = nil
    var selectedPhotoItem: PhotosPickerItem? = nil

    // MARK: Preferences
    var selectedLanguage: String {
        didSet { UserDefaults.standard.set(selectedLanguage, forKey: Keys.language) }
    }
    static let languages = ["English", "Spanish", "French", "German",
                            "Japanese", "Chinese", "Portuguese", "Arabic"]

    // MARK: Storage
    var usedBytes: Int64 = 0
    var totalBytes: Int64 = 0
    var showClearCacheAlert = false

    // MARK: Account alerts
    var showSignOutAlert = false
    var showDeleteAlert = false
    var showDeleteConfirmAlert = false

    // MARK: Init
    init() {
        let ud = UserDefaults.standard
        name     = ud.string(forKey: Keys.name)     ?? ""
        email    = ud.string(forKey: Keys.email)    ?? ""
        profileImageData = ud.data(forKey: Keys.photo)
        selectedLanguage = ud.string(forKey: Keys.language) ?? "English"
        refreshStorage()
    }

    // MARK: Validation
    func validateEmail() {
        guard !email.isEmpty else { emailError = nil; return }
        emailError = Validators.isValidEmail(email) ? nil : "Enter a valid email address"
    }

    // MARK: Storage
    func refreshStorage() {
        guard let attrs = try? FileManager.default
                .attributesOfFileSystem(forPath: NSHomeDirectory()) else { return }
        totalBytes = attrs[.systemSize]     as? Int64 ?? 0
        let free   = attrs[.systemFreeSize] as? Int64 ?? 0
        usedBytes  = totalBytes - free
    }

    var storageRatio: Double {
        totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0
    }

    func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        return String(format: "%.0f MB", Double(bytes) / 1_048_576)
    }

    func clearCache() {
        guard let dir = FileManager.default
                .urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        if let items = try? FileManager.default.contentsOfDirectory(at: dir,
                                                                    includingPropertiesForKeys: nil) {
            items.forEach { try? FileManager.default.removeItem(at: $0) }
        }
        refreshStorage()
    }

    // MARK: Photo loading
    @MainActor
    func loadSelectedPhoto() async {
        guard let item = selectedPhotoItem,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        let side = CGSize(width: 300, height: 300)
        let thumb = image.preparingThumbnail(of: side) ?? image
        profileImageData = thumb.jpegData(compressionQuality: 0.8)
    }

    // MARK: Keys
    private enum Keys {
        static let name     = "settings.name"
        static let email    = "settings.email"
        static let photo    = "settings.photo"
        static let language = "settings.language"
    }
}
```

---

### `ChangePasswordViewModel.swift`
```swift
import Observation

@Observable
final class ChangePasswordViewModel {
    var oldPassword     = ""
    var newPassword     = ""
    var confirmPassword = ""

    var oldPasswordError:     String? = nil
    var newPasswordError:     String? = nil
    var confirmPasswordError: String? = nil

    var isValid: Bool {
        !oldPassword.isEmpty &&
        !newPassword.isEmpty     && newPasswordError     == nil &&
        !confirmPassword.isEmpty && confirmPasswordError == nil
    }

    func validateOldPassword() {
        oldPasswordError = oldPassword.isEmpty ? nil : nil   // length only, no format check
    }

    func validateNewPassword() {
        if newPassword.isEmpty {
            newPasswordError = nil
        } else {
            newPasswordError = Validators.isValidPassword(newPassword)
                ? nil
                : "Must be 8+ chars with 1 uppercase and 1 number"
        }
        if !confirmPassword.isEmpty { validateConfirmPassword() }
    }

    func validateConfirmPassword() {
        if confirmPassword.isEmpty {
            confirmPasswordError = nil
        } else {
            confirmPasswordError = (confirmPassword == newPassword) ? nil : "Passwords do not match"
        }
    }

    /// Touches all fields and returns overall validity.
    func validateAll() -> Bool {
        if oldPassword.isEmpty     { oldPasswordError     = "Current password is required" }
        if newPassword.isEmpty     { newPasswordError     = "New password is required" }
        else                       { validateNewPassword() }
        if confirmPassword.isEmpty { confirmPasswordError = "Please confirm your password" }
        else                       { validateConfirmPassword() }
        return isValid
    }
}
```

---

### `CameraView.swift`
```swift
import SwiftUI
import UIKit

/// Wraps `UIImagePickerController` for in-app camera capture.
/// Requires `NSCameraUsageDescription` in Info.plist.
struct CameraView: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType    = .camera
        picker.allowsEditing = true
        picker.delegate      = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject,
                             UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let key: UIImagePickerController.InfoKey =
                info[.editedImage] != nil ? .editedImage : .originalImage
            if let image = info[key] as? UIImage {
                let side  = CGSize(width: 300, height: 300)
                let thumb = image.preparingThumbnail(of: side) ?? image
                parent.imageData = thumb.jpegData(compressionQuality: 0.8)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
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
            PreferencesSection(viewModel: viewModel)
            StorageSection(viewModel: viewModel)
            AccountSection(viewModel: viewModel)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .scrollDismissesKeyboard(.immediately)
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
    @FocusState private var focus: Field?
    @State private var showOptions  = false
    @State private var showLibrary  = false
    @State private var showCamera   = false

    enum Field { case name, email }

    var body: some View {
        Section("Profile") {

            // ── Avatar ──────────────────────────────────────
            HStack {
                Spacer()
                Button { showOptions = true } label: { avatar }
                    .buttonStyle(.plain)
                Spacer()
            }
            .listRowBackground(Color.clear)
            .padding(.vertical, 8)

            // ── Name ────────────────────────────────────────
            TextField("Name", text: $viewModel.name)
                .textContentType(.name)
                .autocorrectionDisabled()
                .focused($focus, equals: .name)
                .submitLabel(.next)
                .onSubmit { focus = .email }

            // ── Email ───────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.done)
                    .onSubmit { focus = nil }
                    .onChange(of: viewModel.email) { _, _ in viewModel.validateEmail() }

                if let err = viewModel.emailError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .transition(.opacity)
                }
            }
        }
        // Source picker
        .confirmationDialog("Profile Photo", isPresented: $showOptions, titleVisibility: .visible) {
            Button("Take Photo")             { showCamera  = true }
            Button("Choose from Library")   { showLibrary = true }
            if viewModel.profileImageData != nil {
                Button("Remove Photo", role: .destructive) {
                    viewModel.profileImageData = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        // PhotosUI picker (no entitlement needed in iOS 16+)
        .photosPicker(isPresented: $showLibrary,
                      selection: $viewModel.selectedPhotoItem,
                      matching: .images)
        .onChange(of: viewModel.selectedPhotoItem) { _, _ in
            Task { await viewModel.loadSelectedPhoto() }
        }
        // Camera sheet
        .sheet(isPresented: $showCamera) {
            CameraView(imageData: $viewModel.profileImageData)
        }
    }

    // MARK: Avatar view
    @ViewBuilder
    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let data = viewModel.profileImageData,
                   let img  = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGray5))
                }
            }
            .frame(width: 90, height: 90)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.accentColor, lineWidth: 2))

            Image(systemName: "camera.circle.fill")
                .font(.system(size: 26))
                .symbolRenderingMode(.multicolor)
                .background(Color(.systemBackground).clipShape(Circle()))
                .offset(x: 3, y: 3)
        }
    }
}
```

---

### `PreferencesSection.swift`
```swift
import SwiftUI

struct PreferencesSection: View {
    @Bindable var viewModel: SettingsViewModel

    // @AppStorage keys must match SettingsApp's usage for dark mode to propagate.
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("isDarkMode")           private var isDarkMode           = false

    var body: some View {
        Section("Preferences") {
            Toggle("Notifications", isOn: $notificationsEnabled)

            Toggle("Dark Mode", isOn: $isDarkMode)

            Picker("Language", selection: $viewModel.selectedLanguage) {
                ForEach(SettingsViewModel.languages, id: \.self) { lang in
                    Text(lang).tag(lang)
                }
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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Used Space")
                    Spacer()
                    Text("\(viewModel.formatBytes(viewModel.usedBytes)) of \(viewModel.formatBytes(viewModel.totalBytes))")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }

                ProgressView(value: viewModel.storageRatio)
                    .tint(tintColor)
                    .scaleEffect(x: 1, y: 1.4, anchor: .center)
            }
            .padding(.vertical, 4)

            Button("Clear Cache") {
                viewModel.showClearCacheAlert = true
            }
        }
        .alert("Clear Cache?", isPresented: $viewModel.showClearCacheAlert) {
            Button("Clear", role: .destructive) { viewModel.clearCache() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All cached data will be removed. This cannot be undone.")
        }
    }

    private var tintColor: Color {
        switch viewModel.storageRatio {
        case ..<0.7:  return .blue
        case ..<0.9:  return .orange
        default:      return .red
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
                Text("Change Password")
            }

            Button("Sign Out") {
                viewModel.showSignOutAlert = true
            }

            Button("Delete Account") {
                viewModel.showDeleteAlert = true
            }
            .foregroundStyle(.red)
        }
        // Sign out
        .alert("Sign Out?", isPresented: $viewModel.showSignOutAlert) {
            Button("Sign Out", role: .destructive) {
                // TODO: call your auth service
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
        // First delete confirmation
        .alert("Delete Account?", isPresented: $viewModel.showDeleteAlert) {
            Button("Continue", role: .destructive) {
                viewModel.showDeleteConfirmAlert = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account. Do you want to continue?")
        }
        // Second delete confirmation
        .alert("This Cannot Be Undone", isPresented: $viewModel.showDeleteConfirmAlert) {
            Button("Delete Forever", role: .destructive) {
                // TODO: call your auth service
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All your data will be permanently erased and cannot be recovered.")
        }
    }
}
```

---

### `ChangePasswordView.swift`
```swift
import SwiftUI

struct ChangePasswordView: View {
    @State private var passwordVM = ChangePasswordViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?
    @State private var showSuccess = false

    enum Field { case old, new, confirm }

    var body: some View {
        // @Bindable as a local variable enables $vm.property bindings
        @Bindable var vm = passwordVM

        return Form {
            Section {
                passwordRow(label: "Current Password",
                            text: $vm.oldPassword,
                            error: vm.oldPasswordError,
                            field: .old, next: .new,
                            validate: { vm.validateOldPassword() })

                passwordRow(label: "New Password",
                            text: $vm.newPassword,
                            error: vm.newPasswordError,
                            field: .new, next: .confirm,
                            validate: { vm.validateNewPassword() })

                passwordRow(label: "Confirm New Password",
                            text: $vm.confirmPassword,
                            error: vm.confirmPasswordError,
                            field: .confirm, next: nil,
                            validate: { vm.validateConfirmPassword() })

            } footer: {
                Text("Password must be 8+ characters with at least 1 uppercase letter and 1 number.")
                    .font(.caption)
            }

            Section {
                Button("Update Password") {
                    if passwordVM.validateAll() {
                        showSuccess = true
                    }
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .disabled(!passwordVM.isValid)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .alert("Password Updated", isPresented: $showSuccess) {
            Button("OK") { dismiss() }
        } message: {
            Text("Your password has been successfully changed.")
        }
    }

    // MARK: Row builder
    @ViewBuilder
    private func passwordRow(
        label: String,
        text: Binding<String>,
        error: String?,
        field: Field,
        next: Field?,
        validate: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SecureField(label, text: text)
                .focused($focus, equals: field)
                .submitLabel(next != nil ? .next : .done)
                .onSubmit {
                    if let next { focus = next } else { focus = nil }
                }
                .onChange(of: text.wrappedValue) { _, _ in validate() }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity)
            }
        }
    }
}
```

---

**Info.plist entries required** (add these before submitting to App Store or testing camera):

```xml
<key>NSCameraUsageDescription</key>
<string>Used to take a profile photo.</string>
```

`PhotosPicker` (the system picker introduced in iOS 16) does **not** require `NSPhotoLibraryUsageDescription`.
