//
//  AuthView.swift
//  LIVE
//
//  Created by Codex on 6/24/26.
//

import SwiftUI

struct AuthView: View {
    @ObservedObject var authManager: AuthManager
    @State private var mode: AuthMode = .signUp

    var body: some View {
        ZStack {
            AuthBackdrop()

            VStack(spacing: 18) {
                VStack(spacing: 5) {
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

                Picker("Auth mode", selection: $mode) {
                    ForEach(AuthMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Group {
                    switch mode {
                    case .signUp:
                        SignUpView(authManager: authManager)
                    case .login:
                        LoginView(authManager: authManager)
                    }
                }
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
    }
}

private struct SignUpView: View {
    @ObservedObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var displayName = ""

    var body: some View {
        VStack(spacing: 11) {
            AuthTextField(title: "Email", text: $email, keyboard: .emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            AuthSecureField(title: "Password", text: $password)

            AuthTextField(title: "Username", text: $username, keyboard: .default)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            AuthTextField(title: "Display name", text: $displayName, keyboard: .default)

            AuthErrorText(message: authManager.errorMessage)

            Button {
                Task {
                    await authManager.signUp(
                        email: email,
                        password: password,
                        username: username,
                        displayName: displayName
                    )
                }
            } label: {
                AuthButtonLabel(title: authManager.isLoading ? "Creating..." : "Sign Up")
            }
            .disabled(authManager.isLoading)
            .buttonStyle(.plain)
        }
    }
}

private struct LoginView: View {
    @ObservedObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 11) {
            AuthTextField(title: "Email", text: $email, keyboard: .emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            AuthSecureField(title: "Password", text: $password)

            AuthErrorText(message: authManager.errorMessage)

            Button {
                Task {
                    await authManager.login(email: email, password: password)
                }
            } label: {
                AuthButtonLabel(title: authManager.isLoading ? "Logging in..." : "Login")
            }
            .disabled(authManager.isLoading)
            .buttonStyle(.plain)
        }
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case signUp = "Sign Up"
    case login = "Login"

    var id: String { rawValue }
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
