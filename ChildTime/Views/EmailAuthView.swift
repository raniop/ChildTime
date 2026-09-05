import SwiftUI

/// Email + password sign-up / sign-in sheet. A third option alongside Apple and
/// Google on the login gate. Names, emails, passwords are handled by Firebase
/// Auth; we never store the password ourselves.
struct EmailAuthView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    enum Mode { case signIn, signUp }
    @State private var mode: Mode = .signUp
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var working = false

    private var canSubmit: Bool {
        email.contains("@") && password.count >= 6 &&
        (mode == .signIn || !name.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("מצב", selection: $mode) {
                        Text("הרשמה").tag(Mode.signUp)
                        Text("כניסה").tag(Mode.signIn)
                    }
                    .pickerStyle(.segmented)
                }
                .glassRows()

                Section("פרטי החשבון") {
                    if mode == .signUp {
                        RTLTextField(placeholder: "שם ההורה", text: $name)
                            .frame(height: 24)
                    }
                    TextField("אימייל", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    // Password row: pinned LTR like the email field (in the RTL
                    // form the secure dots drifted to the RIGHT — Rani), with an
                    // 👁 reveal toggle so users can verify what they typed.
                    HStack {
                        Group {
                            if showPassword {
                                TextField("סיסמה (לפחות 6 תווים)", text: $password)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("סיסמה (לפחות 6 תווים)", text: $password)
                            }
                        }
                        .environment(\.layoutDirection, .leftToRight)
                        .multilineTextAlignment(.leading)
                        Button { showPassword.toggle() } label: {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(showPassword ? "הסתר סיסמה" : "הצג סיסמה")
                    }
                }
                .glassRows()

                if mode == .signIn {
                    Section {
                        Button("שכחתי סיסמה") {
                            Task { await auth.sendPasswordReset(to: email) }
                        }
                        .disabled(!email.contains("@"))
                        .font(.caption)
                    }
                    .glassRows()
                }

                if let info = auth.infoMessage {
                    Section { Text(info).foregroundStyle(.green).font(.caption) }
                    .glassRows()
                }
                if let err = auth.lastError {
                    Section { Text(err).foregroundStyle(.red).font(.caption) }
                    .glassRows()
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if working { ProgressView() }
                            else { Text(mode == .signUp ? "צור חשבון" : "התחבר").fontWeight(.bold) }
                            Spacer()
                        }
                    }
                    .disabled(!canSubmit || working)
                }
                .glassRows()
            }
            .glassForm()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("חשבון הורה")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("בטל") { dismiss() } }
            }
            .onChangeCompat(of: auth.isSignedIn) { _, signedIn in
                if signedIn { dismiss() }
            }
        }
    }

    private func submit() async {
        working = true
        defer { working = false }
        switch mode {
        case .signUp: await auth.signUpWithEmail(email, password: password, displayName: name)
        case .signIn: await auth.signInWithEmail(email, password: password)
        }
    }
}
