import SwiftUI

@main
struct SettingsApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            SettingsView()
                .environment(appState)
                .preferredColorScheme(appState.isDarkMode ? .dark : .light)
        }
    }
}

import SwiftUI

/// Holds settings that must propagate app-wide (e.g., color scheme).
/// All other preferences use @AppStorage directly in their views.
@Observable
final class AppState {
    var isDarkMode: Bool {
        didSet { UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode") }
    }

    init() {
        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
    }
}

import Foundation

enum Validator {
    static func email(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "Email is required" }
        let pattern = #"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        guard trimmed.range(of: pattern, options: .regularExpression) != nil else {
            return "Enter a valid email address"
        }
        return nil
    }

    static func password(_ value: String) -> String? {
        guard !value.isEmpty else { return "Password is required" }
        guard value.count >= 8 else { return "Must be at least 8 characters" }
        guard value.contains(where: \.isUppercase) else { return "Must include an uppercase letter" }
        guard value.contains(where: \.isNumber)    else { return "Must include a number" }
        return nil
    }

    static func confirmPassword(_ new: String, confirm: String) -> String? {
        guard new == confirm else { return "Passwords do not match" }
        return nil
    }
}

import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            List {
                ProfileSectionView()
                PreferencesSectionView()
                StorageSectionView()
                AccountSectionView()
            }
            .navigationTitle("Settings")
            .listStyle(.insetGrouped)
            .scrollDismissesKeyboard(.immediately)
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppState())
}

import SwiftUI
import PhotosUI

struct ProfileSectionView: View {
    // Primitive prefs persist directly via @AppStorage
    @AppStorage("profileName")  private var name  = ""
    @AppStorage("profileEmail") private var email = ""

    // Image stored in Documents dir; @AppStorage for large Data is inappropriate
    @State private var profileImage: UIImage? = nil
    @State private var photosItem:   PhotosPickerItem? = nil
    @State private var nameError:    String? = nil
    @State private var emailError:   String? = nil

    @FocusState private var focus: Field?
    private enum Field: Hashable { case name, email }

    // MARK: - Computed

    private static let imageURL: URL = {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile_photo.jpg")
    }()

    // MARK: - Body

    var body: some View {
        Section("Profile") {
            photoRow
            nameRow
            emailRow
        }
        .onAppear(perform: loadStoredImage)
        .onChange(of: photosItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                saveImage(data)
            }
        }
    }

    // MARK: - Subviews

    private var photoRow: some View {
        HStack {
            Spacer()
            PhotosPicker(selection: $photosItem, matching: .images, photoLibrary: .shared()) {
                avatar
            }
            Spacer()
        }
        .listRowBackground(Color.clear)
    }

    private var avatar: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let img = profileImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .padding(22)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 90, height: 90)
            .background(Color(.systemGray5))
            .clipShape(Circle())

            Image(systemName: "camera.fill")
                .font(.caption)
                .padding(6)
                .background(.tint)
                .foregroundStyle(.white)
                .clipShape(Circle())
                .offset(x: 2, y: 2)
        }
    }

    private var nameRow: some View {
        validatedField(
            label: "Full Name",
            text: $name,
            error: nameError,
            field: .name,
            next: .email,
            keyboardType: .default,
            contentType: .name
        )
        .onChange(of: name) { _, v in
            nameError = v.trimmingCharacters(in: .whitespaces).isEmpty ? "Name is required" : nil
        }
    }

    private var emailRow: some View {
        validatedField(
            label: "Email",
            text: $email,
            error: emailError,
            field: .email,
            next: nil,
            keyboardType: .emailAddress,
            contentType: .emailAddress
        )
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .onChange(of: email) { _, v in
            emailError = v.isEmpty ? nil : Validator.email(v)
        }
    }

    // MARK: - Builder

    @ViewBuilder
    private func validatedField(
        label: String,
        text: Binding<String>,
        error: String?,
        field: Field,
        next: Field?,
        keyboardType: UIKeyboardType,
        contentType: UITextContentType
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField(label, text: text)
                .focused($focus, equals: field)
                .keyboardType(keyboardType)
                .textContentType(contentType)
                .submitLabel(next == nil ? .done : .next)
                .onSubmit { focus = next }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: error != nil)
    }

    // MARK: - Image persistence

    private func loadStoredImage() {
        guard let data = try? Data(contentsOf: Self.imageURL) else { return }
        profileImage = UIImage(data: data)
    }

    private func saveImage(_ data: Data) {
        try? data.write(to: Self.imageURL)
        profileImage = UIImage(data: data)
    }
}

import SwiftUI

struct PreferencesSectionView: View {
    @Environment(AppState.self) private var appState

    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("preferredLanguage")    private var preferredLanguage    = "English"

    private let languages = ["English", "Spanish", "French", "German", "Japanese", "Chinese"]

    var body: some View {
        Section("Preferences") {
            Toggle("Enable Notifications", isOn: $notificationsEnabled)

            // Dark mode must be bound to AppState so the root view reacts
            Toggle("Dark Mode", isOn: Binding(
                get: { appState.isDarkMode },
                set: { appState.isDarkMode = $0 }
            ))

            Picker("Language", selection: $preferredLanguage) {
                ForEach(languages, id: \.self) { Text($0).tag($0) }
            }
        }
    }
}

import SwiftUI

struct StorageSectionView: View {
    @State private var usedBytes:    Int64 = 0
    @State private var totalBytes:   Int64 = 0
    @State private var showAlert:    Bool  = false
    @State private var justCleared:  Bool  = false

    private var fraction: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(usedBytes) / Double(totalBytes))
    }

    private var barTint: Color {
        fraction > 0.9 ? .red : fraction > 0.7 ? .orange : .accentColor
    }

    var body: some View {
        Section("Storage") {
            storageBar
            clearButton
        }
        .onAppear(perform: refresh)
    }

    // MARK: - Subviews

    private var storageBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Used Space")
                Spacer()
                Text("\(formatted(usedBytes)) of \(formatted(totalBytes))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: fraction)
                .tint(barTint)
                .animation(.easeInOut, value: fraction)
        }
        .padding(.vertical, 4)
    }

    private var clearButton: some View {
        Button {
            showAlert = true
        } label: {
            HStack {
                Text("Clear Cache")
                if justCleared {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .tint(.primary)
        .animation(.spring, value: justCleared)
        .alert("Clear Cache?", isPresented: $showAlert) {
            Button("Clear", role: .destructive, action: clearCache)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Temporary files will be removed. This cannot be undone.")
        }
    }

    // MARK: - Helpers

    private func refresh() {
        guard
            let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
            let total = attrs[.systemSize]     as? Int64,
            let free  = attrs[.systemFreeSize] as? Int64
        else { return }
        totalBytes = total
        usedBytes  = total - free
    }

    private func clearCache() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let items = (try? FileManager.default.contentsOfDirectory(
            at: cacheDir, includingPropertiesForKeys: nil
        )) ?? []
        items.forEach { try? FileManager.default.removeItem(at: $0) }

        justCleared = true
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            refresh()
            try? await Task.sleep(for: .seconds(2))
            justCleared = false
        }
    }

    private func formatted(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle  = .file
        f.allowedUnits = [.useMB, .useGB]
        return f.string(fromByteCount: bytes)
    }
}

import SwiftUI

struct AccountSectionView: View {
    @State private var showSignOut:    Bool = false
    @State private var showDelete1:    Bool = false
    @State private var showDelete2:    Bool = false

    var body: some View {
        Section("Account") {
            NavigationLink("Change Password") {
                ChangePasswordView()
            }

            Button("Sign Out") { showSignOut = true }
                .foregroundStyle(.primary)

            Button("Delete Account") { showDelete1 = true }
                .foregroundStyle(.red)
        }
        // Sign out — single confirmation
        .alert("Sign Out", isPresented: $showSignOut) {
            Button("Sign Out", role: .destructive, action: handleSignOut)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
        // Delete — first confirmation
        .alert("Delete Account", isPresented: $showDelete1) {
            Button("Continue", role: .destructive) { showDelete2 = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deleting your account is permanent. All data will be erased and cannot be recovered.")
        }
        // Delete — second (final) confirmation
        .alert("Final Confirmation", isPresented: $showDelete2) {
            Button("Permanently Delete", role: .destructive, action: handleDeleteAccount)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This is irreversible. Your account and every piece of associated data will be gone forever.")
        }
    }

    // MARK: - Actions

    private func handleSignOut() {
        UserDefaults.standard.removeObject(forKey: "authToken")
        // Post notification / set auth state to trigger nav to login
    }

    private func handleDeleteAccount() {
        // Call DELETE /account API, then wipe local state
        if let id = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: id)
        }
        // Navigate to onboarding
    }
}

import SwiftUI

struct ChangePasswordView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var oldError:     String? = nil
    @State private var newError:     String? = nil
    @State private var confirmError: String? = nil
    @State private var isLoading    = false
    @State private var showSuccess  = false

    @FocusState private var focus: Field?
    private enum Field: Hashable { case old, new, confirm }

    private var isValid: Bool {
        !oldPassword.isEmpty && !newPassword.isEmpty && !confirmPassword.isEmpty
            && oldError == nil && newError == nil && confirmError == nil
    }

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                passwordRow(
                    label: "Current Password",
                    text: $oldPassword,
                    error: oldError,
                    field: .old,
                    next: .new,
                    contentType: .password
                )
                passwordRow(
                    label: "New Password",
                    text: $newPassword,
                    error: newError,
                    field: .new,
                    next: .confirm,
                    contentType: .newPassword
                )
                passwordRow(
                    label: "Confirm New Password",
                    text: $confirmPassword,
                    error: confirmError,
                    field: .confirm,
                    next: nil,
                    contentType: .newPassword
                )
            } footer: {
                Text("At least 8 characters · one uppercase letter · one number")
                    .font(.caption)
            }

            Section {
                Button(action: submit) {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text("Update Password").fontWeight(.semibold)
                        }
                        Spacer()
                    }
                }
                .disabled(!isValid || isLoading)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.immediately)
        .alert("Password Updated", isPresented: $showSuccess) {
            Button("Done") { dismiss() }
        } message: {
            Text("Your password has been changed successfully.")
        }
        // Validate new password as user types, and keep confirm in sync
        .onChange(of: newPassword) { _, v in
            newError = v.isEmpty ? nil : Validator.password(v)
            if !confirmPassword.isEmpty {
                confirmError = Validator.confirmPassword(v, confirm: confirmPassword)
            }
        }
        // Validate confirm as user types
        .onChange(of: confirmPassword) { _, v in
            confirmError = v.isEmpty ? nil : Validator.confirmPassword(newPassword, confirm: v)
        }
    }

    // MARK: - Row builder

    @ViewBuilder
    private func passwordRow(
        label: String,
        text: Binding<String>,
        error: String?,
        field: Field,
        next: Field?,
        contentType: UITextContentType
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SecureField(label, text: text)
                .focused($focus, equals: field)
                .textContentType(contentType)
                .submitLabel(next == nil ? .done : .next)
                .onSubmit {
                    if let next {
                        focus = next
                    } else {
                        focus = nil
                        if isValid { submit() }
                    }
                }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: error != nil)
    }

    // MARK: - Submit

    private func submit() {
        // Force-validate all fields on explicit submission
        oldError     = oldPassword.isEmpty     ? "Current password is required" : nil
        newError     = Validator.password(newPassword)
        confirmError = Validator.confirmPassword(newPassword, confirm: confirmPassword)
        guard isValid else { return }

        focus     = nil
        isLoading = true

        Task {
            // Replace with real API call
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run {
                isLoading   = false
                showSuccess = true
            }
        }
    }
}

