// Migrations/CreateNewsItem.swift
import Fluent

struct CreateNewsItem: AsyncMigration {
    func prepare(on db: any Database) async throws {
        try await db.schema("news_items")
            .id()
            .field("title_en", .string, .required)
            .field("title_vi", .string, .required)
            .field("cover_url", .string)
            .field("location", .string)
            .field("body_en", .string)
            .field("body_vi", .string)
            .field("event_date", .datetime)
            .field("is_published", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on db: any Database) async throws {
        try await db.schema("news_items").delete()
    }
}
