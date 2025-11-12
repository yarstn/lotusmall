import Vapor
import Fluent

final class User: Model, Content, @unchecked Sendable, Authenticatable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "phone")
    var phone: String

    @Field(key: "email")
    var email: String

    @Field(key: "passwordHash")
    var passwordHash: String

    // بلد المنشأ (قد تكون فارغة)
    @Field(key: "origin_country")
    var originCountry: String

    // يحدد إذا كان بائع
    @Field(key: "isSeller")
    var isSeller: Bool

    // هل أدمن
    @Field(key: "is_admin")
    var isAdmin: Bool

    // توقيت الإنشاء (اختياري إن كان موجود بالمخطط)
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(name: String, email: String, passwordHash: String, phone: String, isSeller: Bool = false) {
        self.name = name
        self.phone = phone
        self.email = email
        self.passwordHash = passwordHash
        self.isSeller = isSeller
        self.isAdmin = false
        self.originCountry = ""
    }
}
