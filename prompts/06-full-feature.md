Build a complete "Settings" screen for an iOS app using SwiftUI. Requirements:
- Profile section: circular photo (tap to pick from camera/library via PhotosUI), name field, email field
- Preferences section: toggle for notifications, toggle for dark mode (actually applies to app), picker for preferred language
- Storage section: shows used/total space with a progress bar, "Clear Cache" button with confirmation alert
- Account section: "Change Password" (navigates to form with old/new/confirm fields and validation), "Sign Out" button with confirmation, "Delete Account" in red with double confirmation
- All settings persist via UserDefaults (use @AppStorage where appropriate)
- Form validation: email must be valid format, password must be 8+ chars with 1 uppercase and 1 number, confirm must match
- Show inline validation errors below fields as they type
- Proper keyboard handling: dismiss on tap outside, return key moves to next field

Use iOS 17+ APIs (@Observable, etc). Output all code in logically separated files. Do not include unit tests or XCTest code. All code must compile as a single iOS app target — no test targets, no XCTest imports, no @testable.