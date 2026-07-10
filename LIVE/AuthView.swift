//
//  AuthView.swift
//  LIVE
//
//  Created by Codex on 6/24/26.
//

import AuthenticationServices
import CryptoKit
import SwiftUI

struct AuthView: View {
    @ObservedObject var authManager: AuthManager
    @State private var currentNonce: String?

    var body: some View {
        ZStack {
            AuthBackdrop()

            VStack(spacing: 20) {
                VStack(spacing: 7) {
                    Text("L!V!N")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.liveSky, Color.liveLavender, Color.liveCoral],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Post the places you actually went.")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.liveMuted)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Start with Apple ID")
                        .font(.system(size: 23, weight: .black, design: .rounded))
                        .foregroundStyle(Color.liveInk)

                    Text("No passwords. No email verification loop. Apple signs you in, then L!V!N lets you claim your handle.")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.liveMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SignInWithAppleButton(.signIn) { request in
                    let nonce = AppleSignInNonce.random()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AppleSignInNonce.sha256(nonce)
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        guard
                            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                            let nonce = currentNonce,
                            let tokenData = credential.identityToken,
                            let idToken = String(data: tokenData, encoding: .utf8)
                        else {
                            authManager.setAuthError("Apple did not return a valid sign-in token. Try again.")
                            return
                        }

                        let name = PersonNameComponentsFormatter.localizedString(
                            from: credential.fullName ?? PersonNameComponents(),
                            style: .medium
                        )
                        Task {
                            await authManager.loginWithApple(
                                idToken: idToken,
                                nonce: nonce,
                                displayName: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name
                            )
                        }
                    case .failure(let error):
                        authManager.setAuthError(error.localizedDescription)
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                AuthErrorText(message: authManager.errorMessage)

                Text("Existing L!V!N profile data stays in Supabase. If an old email account does not automatically map to the Apple auth user, keep the old row and migrate/link it server-side later rather than deleting anything.")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.liveMuted)
                    .lineSpacing(3)
            }
            .padding(20)
            .background(Color.liveSurface.opacity(0.86), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.liveStroke, lineWidth: 1)
            }
            .padding(18)
        }
    }
}

struct ProfileOnboardingView: View {
    @ObservedObject var authManager: AuthManager
    @State private var username = ""
    @State private var displayName = ""
    @State private var useAppleName = false

    var body: some View {
        ZStack {
            AuthBackdrop()

            VStack(alignment: .leading, spacing: 16) {
                Text("Create your profile")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(Color.liveInk)

                Text("This makes your live snaps show with your name on the map.")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.liveMuted)

                AuthTextField(title: "Username", text: $username, keyboard: .default)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if let appleName = authManager.appleSuggestedDisplayName, !appleName.isEmpty {
                    Toggle(isOn: $useAppleName) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Use Apple ID name")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundStyle(Color.liveInk)
                            Text(appleName)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.liveMuted)
                        }
                    }
                    .toggleStyle(.switch)
                    .onChange(of: useAppleName) { _, enabled in
                        if enabled {
                            displayName = appleName
                        }
                    }
                }

                AuthTextField(title: "Display name", text: $displayName, keyboard: .default)

                AuthErrorText(message: authManager.errorMessage)

                Button {
                    Task {
                        await authManager.createMissingProfile(username: username, displayName: displayName)
                    }
                } label: {
                    AuthButtonLabel(title: authManager.isLoading ? "Creating..." : "Enter L!V!N")
                }
                .disabled(authManager.isLoading)
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color.liveSurface.opacity(0.9), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.liveStroke, lineWidth: 1)
            }
            .padding(18)
        }
        .onAppear {
            if displayName.isEmpty, let appleName = authManager.appleSuggestedDisplayName, !appleName.isEmpty {
                useAppleName = true
                displayName = appleName
            }
        }
    }
}

private enum AppleSignInNonce {
    static func random(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce.")
            }

            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }

        return result
    }

    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hashed = SHA256.hash(data: data)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}

private struct AuthTextField: View {
    let title: String
    @Binding var text: String
    let keyboard: UIKeyboardType

    var body: some View {
        TextField(title, text: $text)
            .keyboardType(keyboard)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Color.liveInk)
            .padding(13)
            .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.liveStroke, lineWidth: 1)
            }
    }
}

private struct AuthSecureField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        SecureField(title, text: $text)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Color.liveInk)
            .padding(13)
            .background(Color.liveSurfaceElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.liveStroke, lineWidth: 1)
            }
    }
}

private struct AuthButtonLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .black, design: .rounded))
            .foregroundStyle(Color.liveOnInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.liveInk, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct AuthErrorText: View {
    let message: String?

    var body: some View {
        if let message, !message.isEmpty {
            Text(message)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.liveAlertRed)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
        }
    }
}

private struct AuthBackdrop: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.liveSky.opacity(0.26),
                Color.liveCanvas,
                Color.liveLavender.opacity(0.22),
                Color.liveCoral.opacity(0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
