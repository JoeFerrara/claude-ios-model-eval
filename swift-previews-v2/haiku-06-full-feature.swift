// MARK: - App Entry Point
import SwiftUI
import PhotosUI

@main
struct SettingsApp: App {
    @State private var colorScheme: ColorScheme?
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorScheme)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DarkModeChanged"))) { _ in
                    updateColorScheme()
                }
                .onAppear {
                    updateColorScheme()
                }
        }
    }
    
    private func updateColorScheme() {
        let isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        colorScheme = isDarkMode ? .dark : .light
    }
}

// MARK: - Main Content View
struct ContentView: View {
    var body: some View {
        NavigationStack {
            SettingsView()
        }
    }
}

// MARK: - Models & View Models
@Observable
class SettingsViewModel {
    var userProfile: UserProfile = .loadFromDefaults()
    
    func saveProfile() {
        userProfile.saveToDefaults()
    }
}

struct UserProfile: Codable {
    var name: String = ""
    var email: String = ""
    var profileImageData: Data?
    
    static func loadFromDefaults() -> UserProfile {
        if let data = UserDefaults.standard.data(forKey: "userProfile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return profile
        }
        return UserProfile()
    }
    
    func saveToDefaults() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "userProfile")
        }
    }
}

// MARK: - Validation Utilities
struct ValidationRules {
    static func isValidEmail(_ email: String) -> Bool {
        let pattern = "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: email)
    }
    
    static func isValidPassword(_ password: String) -> Bool {
        let hasMinLength = password.count >= 8
        let hasUppercase = password.contains { $0.isUppercase }
        let hasNumber = password.contains { $0.isNumber }
        return hasMinLength && hasUppercase && hasNumber
    }
    
    static func passwordErrors(_ password: String) -> [String] {
        var errors: [String] = []
        if password.count < 8 {
            errors.append("At least 8 characters")
        }
        if !password.contains(where: { $0.isUppercase }) {
            errors.append("1 uppercase letter")
        }
        if !password.contains(where: { $0.isNumber }) {
            errors.append("1 number")
        }
        return errors
    }
}

// MARK: - Main Settings View
struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    @State private var selectedTab = 0
    
    var body: some View {
        List {
            profileSection
            preferencesSection
            storageSection
            accountSection
        }
        .navigationTitle("Settings")
        .listStyle(.grouped)
    }
    
    // MARK: Profile Section
    private var profileSection: some View {
        Section("Profile") {
            VStack(spacing: 16) {
                ProfilePhotoPickerView(imageData: $viewModel.userProfile.profileImageData)
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
                            .autocorrectionDisabled()
                            .onChange(of: viewModel.userProfile.email) {
                                viewModel.saveProfile()
                            }
                        
                        if !viewModel.userProfile.email.isEmpty && !ValidationRules.isValidEmail(viewModel.userProfile.email) {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.red)
                                Text("Invalid email format")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: Preferences Section
    private var preferencesSection: some View {
        Section("Preferences") {
            Toggle("Notifications", isOn: .init(
                get: { UserDefaults.standard.bool(forKey: "notificationsEnabled") },
                set: { UserDefaults.standard.set($0, forKey: "notificationsEnabled") }
            ))
            
            Toggle("Dark Mode", isOn: .init(
                get: { UserDefaults.standard.bool(forKey: "isDarkMode") },
                set: { newValue in
                    UserDefaults.standard.set(newValue, forKey: "isDarkMode")
                    NotificationCenter.default.post(name: NSNotification.Name("DarkModeChanged"), object: nil)
                }
            ))
            
            Picker("Language", selection: .init(
                get: { UserDefaults.standard.string(forKey: "preferredLanguage") ?? "English" },
                set: { UserDefaults.standard.set($0, forKey: "preferredLanguage") }
            )) {
                Text("English").tag("English")
                Text("Spanish").tag("Spanish")
                Text("French").tag("French")
                Text("German").tag("German")
                Text("Chinese").tag("Chinese")
            }
        }
    }
    
    // MARK: Storage Section
    private var storageSection: some View {
        Section("Storage") {
            StorageSectionView()
        }
    }
    
    // MARK: Account Section
    private var accountSection: some View {
        Section("Account") {
            NavigationLink(destination: ChangePasswordView()) {
                HStack {
                    Text("Change Password")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .foregroundColor(.primary)
            
            SignOutButtonView()
            
            DeleteAccountButtonView()
        }
    }
}

// MARK: - Profile Photo Picker
struct ProfilePhotoPickerView: View {
    @Binding var imageData: Data?
    @State private var selectedItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var cameraImage: UIImage?
    
    var body: some View {
        VStack {
            ZStack {
                if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.blue, lineWidth: 2))
            .menu {
                PhotosPicker(selection: $selectedItem, matching: .images, label: {
                    Label("Photo Library", systemImage: "photo.stack")
                })
                
                Button(action: { showCamera = true }) {
                    Label("Camera", systemImage: "camera")
                }
            }
            .onChange(of: selectedItem) {
                Task {
                    if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                        imageData = data
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView(image: $cameraImage)
                    .onChange(of: cameraImage) {
                        if let image = cameraImage, let data = image.jpegData(compressionQuality: 0.8) {
                            imageData = data
                        }
                    }
            }
            
            Text("Tap to change photo")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Camera Picker
struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        
        init(_ parent: CameraPickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Storage Section
struct StorageSectionView: View {
    @State private var usedSpace: Int64 = 0
    @State private var totalSpace: Int64 = 0
    @State private var showClearCacheAlert = false
    
    var usedPercentage: Double {
        totalSpace > 0 ? Double(usedSpace) / Double(totalSpace) : 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Storage Used")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text("\(formatBytes(usedSpace)) / \(formatBytes(totalSpace))")
                        .font(.headline)
                }
                Spacer()
            }
            
            ProgressView(value: usedPercentage)
                .tint(.blue)
            
            Button(action: { showClearCacheAlert = true }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Clear Cache")
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
                .foregroundColor(.red)
            }
            .alert("Clear Cache?", isPresented: $showClearCacheAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    clearCache()
                }
            } message: {
                Text("This will clear cached data but won't delete your personal files.")
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            calculateStorage()
        }
    }
    
    private func calculateStorage() {
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            usedSpace = calculateDirectorySize(documentsURL)
        }
        
        var totalSpace: Int64 = 0
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            if let space = attributes[.systemSize] as? NSNumber {
                totalSpace = space.int64Value
            }
        } catch {}
        self.totalSpace = totalSpace
    }
    
    private func calculateDirectorySize(_ url: URL) -> Int64 {
        var size: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                   let fileSize = attributes[.size] as? Int64 {
                    size += fileSize
                }
            }
        }
        return size
    }
    
    private func clearCache() {
        if let documentsURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            do {
                let files = try FileManager.default.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                for file in files {
                    try FileManager.default.removeItem(at: file)
                }
                calculateStorage()
            } catch {}
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
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
    @Environment(\.dismiss) var dismiss
    @FocusState private var focusedField: FocusField?
    
    enum FocusField {
        case oldPassword
        case newPassword
        case confirmPassword
    }
    
    var isFormValid: Bool {
        !oldPassword.isEmpty &&
        ValidationRules.isValidPassword(newPassword) &&
        confirmPassword == newPassword
    }
    
    var body: some View {
        Form {
            Section("Current Password") {
                HStack {
                    if showOldPassword {
                        TextField("Password", text: $oldPassword)
                    } else {
                        SecureField("Password", text: $oldPassword)
                    }
                    Button(action: { showOldPassword.toggle() }) {
                        Image(systemName: showOldPassword ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                }
                .focused($focusedField, equals: .oldPassword)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .newPassword
                }
            }
            
            Section("New Password") {
                HStack {
                    if showNewPassword {
                        TextField("Password", text: $newPassword)
                    } else {
                        SecureField("Password", text: $newPassword)
                    }
                    Button(action: { showNewPassword.toggle() }) {
                        Image(systemName: showNewPassword ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                }
                .focused($focusedField, equals: .newPassword)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .confirmPassword
                }
                
                if !newPassword.isEmpty {
                    let errors = ValidationRules.passwordErrors(newPassword)
                    if errors.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Password is valid")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Password must have:")
                                .font(.caption)
                                .foregroundColor(.red)
                            ForEach(errors, id: \.self) { error in
                                HStack {
                                    Image(systemName: "circle")
                                        .font(.caption)
                                    Text(error)
                                        .font(.caption)
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            
            Section("Confirm Password") {
                HStack {
                    if showConfirmPassword {
                        TextField("Password", text: $confirmPassword)
                    } else {
                        SecureField("Password", text: $confirmPassword)
                    }
                    Button(action: { showConfirmPassword.toggle() }) {
                        Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                            .foregroundColor(.gray)
                    }
                }
                .focused($focusedField, equals: .confirmPassword)
                .submitLabel(.done)
                
                if !confirmPassword.isEmpty {
                    if confirmPassword == newPassword {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Passwords match")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Passwords don't match")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            Section {
                Button(action: changePassword) {
                    HStack {
                        Spacer()
                        Text("Change Password")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .foregroundColor(.white)
                }
                .listRowBackground(isFormValid ? Color.blue : Color.gray.opacity(0.5))
                .disabled(!isFormValid)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Password Changed", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your password has been successfully updated.")
        }
    }
    
    private func changePassword() {
        UserDefaults.standard.set(newPassword, forKey: "userPassword")
        showSuccess = true
    }
}

// MARK: - Sign Out Button
struct SignOutButtonView: View {
    @State private var showConfirmation = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Button(action: { showConfirmation = true }) {
            HStack {
                Image(systemName: "arrow.right.square")
                Text("Sign Out")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .foregroundColor(.blue)
        .alert("Sign Out?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    private func signOut() {
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        NotificationCenter.default.post(name: NSNotification.Name("UserSignedOut"), object: nil)
    }
}

// MARK: - Delete Account Button
struct DeleteAccountButtonView: View {
    @State private var showFirstConfirmation = false
    @State private var showSecondConfirmation = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Button(action: { showFirstConfirmation = true }) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                Text("Delete Account")
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .foregroundColor(.red)
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
                deleteAccount()
            }
        } message: {
            Text("Are you absolutely sure? Type your email to confirm.")
        }
    }
    
    private func deleteAccount() {
        UserDefaults.standard.removeObject(forKey: "userProfile")
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        NotificationCenter.default.post(name: NSNotification.Name("AccountDeleted"), object: nil)
    }
}

// MARK: - Keyboard Handling
#Preview {
    NavigationStack {
        SettingsView()
    }
}

