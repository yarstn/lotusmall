import Vapor
import Fluent

enum InquiryStatus: String, Codable, CaseIterable {
    case new        // طلب جديد
    case contacted  // تم التواصل
    case closed     // انتهى
}

final class Inquiry: Model, Content, @unchecked Sendable {
    static let schema = "inquiries"

    @ID(key: .id) var id: UUID?

    // الطلب مرتبط بإعلان معيّن
    @Parent(key: "listing_id") var listing: Listing

    // بيانات المشتري
    @Field(key: "buyerName") var buyerName: String
    @Field(key: "buyerPhone") var buyerPhone: String
    @OptionalField(key: "buyerEmail") var buyerEmail: String?

    // تفاصيل الطلب
    @Field(key: "quantity") var quantity: Int
    @OptionalField(key: "message") var message: String?

    // حالة الطلب
    @Field(key: "status") var status: InquiryStatus

    // طوابع وقت اختيارية (متى انشئ/تحدّث)
    @Timestamp(key: "createdAt", on: .create) var createdAt: Date?
    @Timestamp(key: "updatedAt", on: .update) var updatedAt: Date?

    init() {}

    init(listingID: UUID, buyerName: String, buyerPhone: String, buyerEmail: String? = nil,
         quantity: Int, message: String? = nil, status: InquiryStatus = .new) {
        self.$listing.id = listingID
        self.buyerName = buyerName
        self.buyerPhone = buyerPhone
        self.buyerEmail = buyerEmail
        self.quantity = quantity
        self.message = message
        self.status = status
    }
}
