import Fluent
import FluentSQL

struct CreateContactMessage: AsyncMigration {
    func prepare(on db: any Database) async throws {
        try await db.schema("contact_messages")
            .id()
            .field("name", .string, .required)
            .field("email", .string, .required)
            .field("phone", .string, .required)
            .field("company", .string)
            .field("message", .string, .required)
            .field("status", .string, .required)
            // 👇 صار يشتغل بعد إضافة FluentSQL
            .field("responded_by", .string, .sql(.default(SQLLiteral.null)))
            .field("created_at", .datetime)
            .create()
    }

    func revert(on db: any Database) async throws {
        try await db.schema("contact_messages").delete()
    }
}
