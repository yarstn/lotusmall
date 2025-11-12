import Fluent

struct CreateInquiry: AsyncMigration {
    func prepare(on db: any Database) async throws {
        try await db.schema("inquiries")
            .id() // UUID
            // ربط الطلب بإعلان موجود
            .field("listing_id", .uuid, .required,
                   .references("listing", "id", onDelete: .cascade))
            // بيانات المشتري
            .field("buyerName", .string, .required)
            .field("buyerPhone", .string, .required)
            .field("buyerEmail", .string) // اختياري
            // تفاصيل الطلب
            .field("quantity", .int, .required)
            .field("message", .string) // اختياري
            // حالة الطلب (نخزنها كنص: new / contacted / closed)
            .field("status", .string, .required)
            // طوابع الوقت
            .field("createdAt", .datetime)
            .field("updatedAt", .datetime)
            .create()
    }

    func revert(on db: any Database) async throws {
        try await db.schema("inquiries").delete()
    }
}
