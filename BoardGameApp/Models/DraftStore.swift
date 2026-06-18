import Foundation
import Observation

@MainActor
@Observable
final class DraftStore {
    private var drafts: [String: CreateRecordViewModel] = [:]

    func draft(for game: GameDefinition) -> CreateRecordViewModel {
        if let existing = drafts[game.slug] {
            return existing
        }
        let vm = CreateRecordViewModel(game: game)
        drafts[game.slug] = vm
        return vm
    }

    func editingDraft(for game: GameDefinition, record: GameRecord) -> CreateRecordViewModel {
        let key = "edit_\(record.id.uuidString)"
        if let existing = drafts[key] {
            return existing
        }
        let vm = CreateRecordViewModel(game: game, editing: record)
        drafts[key] = vm
        return vm
    }

    func discard(slug: String) {
        drafts.removeValue(forKey: slug)
    }

    func hasDraft(slug: String) -> Bool {
        drafts[slug] != nil
    }
}
