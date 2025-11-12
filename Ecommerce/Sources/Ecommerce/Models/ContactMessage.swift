// Models/ContactMessage.swift
import Vapor
import Fluent

final class ContactMessage: Model, Content {
    static let schema = "contact_messages"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name") var name: String
    @Field(key: "email") var email: String
    @Field(key: "phone") var phone: String
    @OptionalField(key: "company") var company: String?
    @Field(key: "message") var message: String
    @Field(key: "status") var status: String
    @OptionalField(key: "responded_by") var respondedBy: String?
    @Timestamp(key: "created_at", on: .create) var createdAt: Date?

    init() {}

    // ✅ حطي default للستاتس
    init(name: String, email: String, phone: String, company: String?, message: String, status: String = "new") {
        self.name = name
        self.email = email
        self.phone = phone
        self.company = company
        self.message = message
        self.status = status
    }
}


// ✅ علشان نرضّي Swift Concurrency بدون تغيير خصائص الـModel إلى let
extension ContactMessage: @unchecked Sendable {}
