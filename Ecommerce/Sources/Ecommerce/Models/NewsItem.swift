import Vapor
import Fluent

final class NewsItem: Model, Content, @unchecked Sendable {   // 👈 اضف @unchecked Sendable
    static let schema = "news_items"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title_en")
    var titleEn: String

    @Field(key: "title_vi")
    var titleVi: String

    @OptionalField(key: "cover_url")
    var coverURL: String?

    @OptionalField(key: "location")
    var location: String?

    @OptionalField(key: "body_en")
    var bodyEn: String?

    @OptionalField(key: "body_vi")
    var bodyVi: String?

    @OptionalField(key: "event_date")
    var eventDate: Date?

    @Field(key: "is_published")
    var isPublished: Bool

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        titleEn: String,
        titleVi: String,
        coverURL: String? = nil,
        location: String? = nil,
        bodyEn: String? = nil,
        bodyVi: String? = nil,
        eventDate: Date? = nil,
        isPublished: Bool = true
    ) {
        self.id = id
        self.titleEn = titleEn
        self.titleVi = titleVi
        self.coverURL = coverURL
        self.location = location
        self.bodyEn = bodyEn
        self.bodyVi = bodyVi
        self.eventDate = eventDate
        self.isPublished = isPublished
    }
}
