import Vapor
import Fluent

//sell type one or wholesale

enum UnitType: String, Codable, CaseIterable{
    case piece //one
    case wholesale //more than one
}

//ads
final class Listing: Model, Content, @unchecked Sendable{
    static let schema = "listing"
    
    @ID(key: .id) var id: UUID?
    //THE SELLER NAME
    @Parent(key: "seller_id") var seller:User
    
    //about product
    @Field(key: "title") var title: String
    @Field(key: "desc") var desc: String
    @Field(key: "price") var price: Double
    @Field(key: "minOrderQty") var minOrderQty: Int
    @Field(key: "stock") var stock: Int
    
    //pic store
    @Field(key: "imageUrls") var imageUrls: [String]
    init() {}
    init(sellerID: UUID, title: String, desc: String, price: Double, minOrderQty: Int, stock: Int, imageUrls: [String]) {
        self.$seller.id = sellerID
        self.title = title
        self.desc = desc
        self.price = price
        self.minOrderQty = minOrderQty
        self.stock = stock
        self.imageUrls = imageUrls
    }
}
