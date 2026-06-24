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

    private var authStateTask: Task<Void, Never>?

    var isSignedIn: Bool {
        session != nil
    }

    var currentUserID: UUID? {
        session?.user.id
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
            profile = try await createProfile(
                userID: newSession.user.id,
                username: cleanUsername,
                displayName: cleanDisplayName
            )
        }
    }

    func login(email: String, password: String) async {
        await performAuthAction {
            let newSession = try await supabase.auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            session = newSession
            profile = try await fetchProfile(userID: newSession.user.id)
        }
    }

    func logout() async {
        await performAuthAction {
            try await supabase.auth.signOut()
            session = nil
            profile = nil
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

            profile = try await createProfile(
                userID: userID,
                username: cleanUsername,
                displayName: cleanDisplayName
            )
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
            profile = try await fetchProfile(userID: userID)
            errorMessage = nil
        } catch {
            profile = nil
            errorMessage = error.localizedDescription
        }

        isLoading = false
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
