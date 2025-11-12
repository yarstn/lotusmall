import Fluent

struct ChangePhoneType: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .updateField("phone", .string) // نحول العمود من BigInt إلى String
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .updateField("phone", .int) // في حال رجعنا للخلف نخليه Int
    }
}
