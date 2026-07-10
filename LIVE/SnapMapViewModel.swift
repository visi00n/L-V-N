//
//  SnapMapViewModel.swift
//  LIVE
//
//  Created by Codex on 6/24/26.
//

import Combine
import Foundation
import Supabase

@MainActor
final class SnapMapViewModel: ObservableObject {
    @Published private(set) var snaps: [LiveSnap] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var realtimeWarning: String?

    private let snapService = SnapService()
    private var realtimeTask: Task<Void, Never>?
    private var realtimeChannel: RealtimeChannelV2?

    var statusMessage: String? {
        errorMessage ?? realtimeWarning
    }

    func loadSnaps() async {
        isLoading = true
        errorMessage = nil

        do {
            snaps = try await snapService.fetchPublicSnaps()
        } catch {
            errorMessage = Self.message(for: error)
        }

        isLoading = false
    }

    func postSnap(draft: SnapDraft, currentProfile: Profile?) async throws -> LiveSnap {
        let snap = try await snapService.createSnap(draft: draft, currentProfile: currentProfile)
        upsert(snap)
        return snap
    }

    func startRealtime() {
        guard realtimeTask == nil else { return }

        realtimeTask = Task { [weak self] in
            guard let self else { return }
            await self.listenForMapSnaps()
        }
    }

    func stopRealtime() {
        realtimeTask?.cancel()
        realtimeTask = nil

        if let realtimeChannel {
            Task {
                await supabase.removeChannel(realtimeChannel)
            }
        }

        realtimeChannel = nil
        realtimeWarning = nil
    }

    func reset() {
        stopRealtime()
        snaps = []
        errorMessage = nil
    }

    private func listenForMapSnaps() async {
        let channel = supabase.channel("map:snaps")
        realtimeChannel = channel
        let insertions = channel.postgresChange(InsertAction.self, schema: "public", table: "snaps")

        do {
            try await channel.subscribeWithError()
            realtimeWarning = nil
        } catch {
            realtimeWarning = "Realtime unavailable. Pull to refresh by reopening the map."
            realtimeTask = nil
            return
        }

        for await action in insertions {
            guard !Task.isCancelled else { return }

            do {
                let snap = try action.decodeRecord(as: Snap.self, decoder: AnyJSON.decoder)
                guard snap.isPublic else { continue }
                await loadSnaps()
            } catch {
                await loadSnaps()
            }
        }

        realtimeTask = nil
    }

    func upsert(_ snap: LiveSnap) {
        snaps.removeAll { $0.id == snap.id }
        snaps.insert(snap, at: 0)
    }

    func removeSnap(id: String) {
        snaps.removeAll { $0.id == id }
    }

    func deleteSnap(snapID: String) async throws {
        guard let uuid = UUID(uuidString: snapID) else { return }
        try await snapService.deleteSnap(snapID: uuid)
        snaps.removeAll { $0.id == snapID }
    }

    private static func message(for error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }

        return error.localizedDescription
    }
}
