import Fluent

struct CreateListing: AsyncMigration{
    func prepare(on db: any Database) async throws {
        try await db.schema("listing")
            .id() //uuid
            .field("seller_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("title", .string, .required)
            .field("desc", .string, .required)
            .field("price", .double, .required)
            .field("minOrderQty", .int, .required)
            .field("stock", .int, .required)
            .field("imageUrls", .array(of: .string), .required)
            .create()
        
    }
    func revert(on db: any Database) async throws {
        try await db.schema("listing").delete()
    }
}
