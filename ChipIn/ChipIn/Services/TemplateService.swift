import Foundation
import Supabase

struct ExpenseTemplate: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var name: String
    var title: String
    var category: String
    var splitType: String
    var currency: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, title, category, currency
        case userId = "user_id"
        case splitType = "split_type"
        case createdAt = "created_at"
    }
}

struct TemplateService {
    func fetchTemplates(userId: UUID) async throws -> [ExpenseTemplate] {
        try await supabase
            .from("expense_templates")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func saveTemplate(userId: UUID, name: String, title: String, category: String, splitType: String, currency: String) async throws {
        struct Insert: Encodable {
            let user_id: String
            let name: String
            let title: String
            let category: String
            let split_type: String
            let currency: String
        }
        let payload = Insert(
            user_id: userId.uuidString,
            name: name, title: title,
            category: category, split_type: splitType, currency: currency
        )
        try await supabase.from("expense_templates").insert(payload).execute()
    }

    func deleteTemplate(id: UUID) async throws {
        try await supabase.from("expense_templates").delete().eq("id", value: id).execute()
    }
}
