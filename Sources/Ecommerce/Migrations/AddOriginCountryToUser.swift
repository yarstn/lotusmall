import Fluent

struct AddOriginCountryToUser: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("origin_country", .string, .required, .sql(.default("")))
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("origin_country")
            .update()
    }
}
