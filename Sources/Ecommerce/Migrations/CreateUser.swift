import Fluent
import SQLKit  // مهم

struct CreateUser: AsyncMigration {
    // تُنشئ جدول users عند الهجرة
    func prepare(on db: any Database) async throws {
        try await db.schema("users")
            .id()                                   // عمود id تلقائي (UUID)
            .field("name", .string, .required)
            .field("email", .string, .required)
            .field("phone", .string, .required)
            .unique(on: "email")                    // يمنع تكرار الإيميل
            .field("passwordHash", .string, .required)
            .field("isSeller", .bool, .required, .sql(.default(false)))
            .field("created_at", .datetime)
            .create()
    }

    // تُرجع التغيير (تحذف الجدول) لو عملت rollback
    func revert(on db: any Database) async throws {
        try await db.schema("users").delete()
    }
}



struct AddIsAdminToUser: AsyncMigration {
    func prepare(on db: any Database) async throws {
        // نستخدم SQLKit لتفادي تكرار العمود
        if let sql = db as? any SQLDatabase {
            try await sql.raw("""
                ALTER TABLE "users"
                ADD COLUMN IF NOT EXISTS "is_admin" BOOL NOT NULL DEFAULT FALSE;
            """).run()
        } else {
            // fallback لو ما توفر SQLDatabase
            try await db.schema("users")
                .field("is_admin", .bool, .required, .sql(.default(false)))
                .update()
        }
    }

    func revert(on db: any Database) async throws {
        if let sql = db as? any SQLDatabase {
            try await sql.raw("""
                ALTER TABLE "users"
                DROP COLUMN IF EXISTS "is_admin";
            """).run()
        } else {
            try await db.schema("users")
                .deleteField("is_admin")
                .update()
        }
    }
}

