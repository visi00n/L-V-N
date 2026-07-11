//
//  AuthManager.swift
//  LIVE
//
//  Created by Codex on 6/24/26.
//

import Combine
import Foundation
import Supabase

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var session: Session?
    @Published private(set) var profile: Profile?
    @Published private(set) var isLoading = true
    @Published var errorMessage: String?
    @Published var appleSuggestedDisplayName: String?
    @Published private(set) var hasAppleIdentity = false

    private var authStateTask: Task<Void, Never>?

    var isSignedIn: Bool {
        session != nil || profile != nil
    }

    var currentUserID: UUID? {
        session?.user.id ?? profile?.id
    }

    func start() {
        guard authStateTask == nil else { return }

        authStateTask = Task { [weak self] in
            for await change in supabase.auth.authStateChanges {
                guard let self else { return }
                await self.handleAuthState(session: change.session)
            }
        }
    }

    func signUp(email: String, password: String, username: String, displayName: String) async {
        await performAuthAction {
            let cleanUsername = Self.normalizedUsername(username)
            let cleanDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AuthManagerError.message("Email is required.")
            }
            guard password.count >= 6 else {
                throw AuthManagerError.message("Password needs at least 6 characters.")
            }
            guard !cleanUsername.isEmpty else {
                throw AuthManagerError.message("Username is required.")
            }
            guard !cleanDisplayName.isEmpty else {
                throw AuthManagerError.message("Display name is required.")
            }

            let response = try await supabase.auth.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                data: [
                    "username": .string(cleanUsername),
                    "display_name": .string(cleanDisplayName)
                ]
            )

            guard let newSession = response.session else {
                throw AuthManagerError.message("Account created. Check your email, then log in.")
            }

            session = newSession
            let newProfile = try await createProfile(
                userID: newSession.user.id,
                username: cleanUsername,
                displayName: cleanDisplayName
            )
            profile = newProfile
            saveProfileToCache(newProfile)
        }
    }

    func login(email: String, password: String) async {
        await login(identifier: email, password: password)
    }

    func login(identifier: String, password: String) async {
        await performAuthAction {
            let cleanIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard cleanIdentifier.contains("@") else {
                throw AuthManagerError.message("For account recovery, use your email/Gmail and password. Handle-only login needs a secure server-side username lookup before it can work.")
            }
            let newSession = try await supabase.auth.signIn(
                email: cleanIdentifier,
                password: password
            )
            session = newSession
            if let fetched = try await fetchProfile(userID: newSession.user.id) {
                profile = fetched
                saveProfileToCache(fetched)
            }
            try await refreshAppleIdentityStatus()
        }
    }

    func loginWithApple(idToken: String, nonce: String, displayName: String?) async {
        await performAuthAction {
            let cleanDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let cleanDisplayName, !cleanDisplayName.isEmpty {
                appleSuggestedDisplayName = cleanDisplayName
                UserDefaults.standard.set(cleanDisplayName, forKey: "live_apple_suggested_display_name")
            }

            let newSession = try await supabase.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )

            session = newSession
            if let fetched = try await fetchProfile(userID: newSession.user.id) {
                profile = fetched
                saveProfileToCache(fetched)
            } else {
                profile = nil
            }
            try await refreshAppleIdentityStatus()
        }
    }

    func linkAppleID(idToken: String, nonce: String, displayName: String?) async {
        await performAuthAction {
            let newSession = try await supabase.auth.linkIdentityWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )

            session = newSession
            if let cleanDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines), !cleanDisplayName.isEmpty {
                appleSuggestedDisplayName = cleanDisplayName
            }
            hasAppleIdentity = true
            await refreshProfile()
        }
    }

    func setAuthError(_ message: String) {
        errorMessage = message
        isLoading = false
    }

    func logout() async {
        await performAuthAction {
            try await supabase.auth.signOut()
            session = nil
            profile = nil
            hasAppleIdentity = false
            appleSuggestedDisplayName = nil
            UserDefaults.standard.removeObject(forKey: "live_cached_profile")
        }
    }

    func createMissingProfile(username: String, displayName: String) async {
        await performAuthAction {
            guard let userID = currentUserID else {
                throw AuthManagerError.message("Log in before creating a profile.")
            }

            let cleanUsername = Self.normalizedUsername(username)
            let cleanDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanUsername.isEmpty else {
                throw AuthManagerError.message("Username is required.")
            }
            guard !cleanDisplayName.isEmpty else {
                throw AuthManagerError.message("Display name is required.")
            }

            let newProfile: Profile
            do {
                newProfile = try await createProfile(
                    userID: userID,
                    username: cleanUsername,
                    displayName: cleanDisplayName
                )
            } catch {
                if Self.isDuplicateUsernameError(error) {
                    throw AuthManagerError.message("That username is already taken. Try another handle.")
                }
                throw error
            }
            profile = newProfile
            saveProfileToCache(newProfile)
        }
    }

    func refreshProfile() async {
        guard let userID = currentUserID else { return }
        do {
            if let fetched = try await fetchProfile(userID: userID) {
                profile = fetched
                saveProfileToCache(fetched)
            }
            try await refreshAppleIdentityStatus()
        } catch {
            if profile == nil {
                profile = loadProfileFromCache()
            }
            errorMessage = Self.message(for: error)
        }
    }

    private func handleAuthState(session newSession: Session?) async {
        session = newSession

        guard let userID = newSession?.user.id else {
            profile = nil
            isLoading = false
            return
        }

        do {
            if let fetched = try await fetchProfile(userID: userID) {
                profile = fetched
                saveProfileToCache(fetched)
            } else if let cached = loadProfileFromCache(), cached.id == userID {
                profile = cached
            } else {
                profile = nil
            }
            try await refreshAppleIdentityStatus()
            errorMessage = nil
        } catch {
            if let cached = loadProfileFromCache(), cached.id == userID {
                profile = cached
                errorMessage = nil
            } else {
                profile = nil
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func saveProfileToCache(_ profile: Profile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "live_cached_profile")
        }
    }

    private func loadProfileFromCache() -> Profile? {
        if appleSuggestedDisplayName == nil {
            appleSuggestedDisplayName = UserDefaults.standard.string(forKey: "live_apple_suggested_display_name")
        }
        if let data = UserDefaults.standard.data(forKey: "live_cached_profile"),
           let cached = try? JSONDecoder().decode(Profile.self, from: data) {
            return cached
        }
        return nil
    }

    private func refreshAppleIdentityStatus() async throws {
        guard session != nil else {
            hasAppleIdentity = false
            return
        }
        let identities = try await supabase.auth.userIdentities()
        hasAppleIdentity = identities.contains { $0.provider.lowercased() == "apple" }
    }

    private func performAuthAction(_ action: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil

        do {
            try await action()
        } catch {
            errorMessage = Self.message(for: error)
        }

        isLoading = false
    }

    private func fetchProfile(userID: UUID) async throws -> Profile? {
        let response: PostgrestResponse<[Profile]> = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userID)
            .limit(1)
            .execute()

        return response.value.first
    }

    private func createProfile(userID: UUID, username: String, displayName: String) async throws -> Profile {
        let insert = ProfileInsert(
            id: userID,
            username: username,
            displayName: displayName,
            bio: "",
            isPrivate: false
        )

        let response: PostgrestResponse<[Profile]> = try await supabase
            .from("profiles")
            .upsert(insert, onConflict: "id")
            .select()
            .execute()

        guard let profile = response.value.first else {
            throw AuthManagerError.message("Profile was not returned by Supabase.")
        }

        return profile
    }

    private static func normalizedUsername(_ username: String) -> String {
        username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .lowercased()
    }

    private static func isDuplicateUsernameError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        return message.contains("profiles_username_key")
            || (message.contains("duplicate key") && message.contains("username"))
            || message.contains("already exists")
    }

    private static func message(for error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }

        return error.localizedDescription
    }
}

private enum AuthManagerError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let message):
            message
        }
    }
}
