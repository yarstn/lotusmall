@preconcurrency import Vapor
@preconcurrency import Fluent
import JWT
import Foundation // FileManager, CharacterSet

public func routes(_ app: Application) throws {
    // مجموعة API v1
    let api = app.grouped("api", "v1")
    // محمي بالتوكن (JWT)
    let protected = api.grouped(UserJWTAuthenticator(), User.guardMiddleware())
    // مصادِق بدون guard (يسمح بوجود مستخدم أو لا)
    let maybeAuth = api.grouped(UserJWTAuthenticator())

    // =========================
    // Upload (multipart/form-data)
    // =========================
    struct UploadResponse: Content { let url: String }

    api.on(.POST, "upload", body: .collect(maxSize: "20mb")) { req async throws -> UploadResponse in
        struct UploadData: Content { var file: File } // اسم الحقل يجب أن يكون "file"
        let data = try req.content.decode(UploadData.self)

        let original = data.file.filename
        let ext = original.split(separator: ".").last.map(String.init) ?? "bin"
        let filename = "\(UUID().uuidString).\(ext)"

        let uploadsDir = req.application.directory.publicDirectory + "uploads/"
        try FileManager.default.createDirectory(atPath: uploadsDir, withIntermediateDirectories: true)

        let savePath = uploadsDir + filename
        let fileData = Data(buffer: data.file.data)
        try fileData.write(to: URL(fileURLWithPath: savePath))

        let publicURL = "http://localhost:8080/uploads/\(filename)"
        return UploadResponse(url: publicURL)
    }

    // =========================
    // صفحات تجريبية
    // =========================
    app.get { _ async in "It works!" }
    app.get("hello") { _ async -> String in "Hello, world!" }

    // =========================
    // Users (تجريبية)
    // =========================
    struct CreateUserReq: Content {
        let name: String
        let phone: String
        let email: String
    }

    api.get("users") { req async throws -> [User] in
        try await User.query(on: req.db).all()
    }

    api.post("users") { req async throws -> User in
        let body = try req.content.decode(CreateUserReq.self)
        let user = User(
            name: body.name,
            email: body.email.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased(),
            passwordHash: "temp-hash",
            phone: body.phone,
            isSeller: false
        )
        try await user.save(on: req.db)
        return user
    }

    // =========================
    // Listings
    // =========================
    struct CreateListingReq: Content {
        let title: String
        let desc: String
        let price: Double
        let minOrderQty: Int
        let stock: Int
        let imageUrls: [String]
    }

    // عام: كل الإعلانات (مع فلترة اختيارية حسب بلد منشأ البائع)
    api.get("listings") { req async throws -> [Listing] in
        let byOrigin = (
            (try? req.query.get(String.self, at: "originCountry")) ??
            (try? req.query.get(String.self, at: "origin"))
        )?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if let country = byOrigin, !country.isEmpty {
            return try await Listing.query(on: req.db)
                .join(User.self, on: \Listing.$seller.$id == \User.$id)
                .filter(User.self, \.$originCountry == country)
                .all()
        }

        return try await Listing.query(on: req.db).all()
    }

    // عام: إعلان واحد
    api.get("listings", ":id") { req async throws -> Listing in
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid listing id")
        }
        if let listing = try await Listing.query(on: req.db)
            .with(\.$seller)
            .filter(\.$id == id)
            .first() {
            return listing
        } else {
            throw Abort(.notFound, reason: "Listing not found")
        }
    }

    // محمي: إنشاء إعلان (بائع فقط)
    protected.post("listings") { req async throws -> Listing in
        let user = try req.auth.require(User.self)
        guard user.isSeller else {
            throw Abort(.forbidden, reason: "Only sellers can create listings")
        }

        let body = try req.content.decode(CreateListingReq.self)
        let listing = Listing(
            sellerID: try user.requireID(),
            title: body.title,
            desc: body.desc,
            price: body.price,
            minOrderQty: body.minOrderQty,
            stock: body.stock,
            imageUrls: body.imageUrls
        )
        try await listing.save(on: req.db)
        return listing
    }

    // محمي: إعلاناتي
    protected.get("my", "listings") { req async throws -> [Listing] in
        let authedUser = try req.auth.require(User.self)
        let authedID = try authedUser.requireID()
        return try await Listing.query(on: req.db)
            .filter(\.$seller.$id == authedID)
            .all()
    }

    // =========================
    // Inquiries
    // =========================
    struct CreateInquiryReq: Content {
        let listingID: UUID
        let buyerName: String
        let buyerPhone: String
        let buyerEmail: String?
        let quantity: Int
        let message: String?
    }

    // كل الاستفسارات (عام)
    api.get("inquiries") { req async throws -> [Inquiry] in
        try await Inquiry.query(on: req.db).all()
    }

    // استفسارات إعلان محدد
    api.get("listings", ":id", "inquiries") { req async throws -> [Inquiry] in
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid listing id")
        }
        return try await Inquiry.query(on: req.db)
            .filter(\.$listing.$id == id)
            .all()
    }

    // إنشاء استفسار (يسمح بالزائر أو الموثّق)
    maybeAuth.post("inquiries") { req async throws -> Inquiry in
        let body = try req.content.decode(CreateInquiryReq.self)
        let authUser = req.auth.get(User.self)

        let emailNorm = (authUser?.email ?? body.buyerEmail ?? "")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .lowercased()

        let phoneNorm = (authUser?.phone ?? body.buyerPhone)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        guard try await Listing.find(body.listingID, on: req.db) != nil else {
            throw Abort(.notFound, reason: "Listing not found")
        }

        let inquiry = Inquiry(
            listingID: body.listingID,
            buyerName: body.buyerName,
            buyerPhone: phoneNorm.isEmpty ? "" : phoneNorm,
            buyerEmail: emailNorm.isEmpty ? "" : emailNorm,
            quantity: body.quantity,
            message: body.message,
            status: .new
        )
        try await inquiry.save(on: req.db)
        return inquiry
    }

    // استرجاع استفساراتي (المستخدم المسجّل)
    protected.get("inquiries", "me") { req async throws -> [Inquiry] in
        let me = try req.auth.require(User.self)
        let email = me.email.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()
        guard !email.isEmpty else { return [] }

        return try await Inquiry.query(on: req.db)
            .filter(\.$buyerEmail == email)
            .sort(\.$createdAt, .descending)
            .all()
    }

    // محمي: استفسارات تخص إعلانات البائع (مع فلترة/تقسيم صفحات)
    protected.get("seller", "inquiries") { req async throws -> Page<Inquiry> in
        let authedUser = try req.auth.require(User.self)
        let authedID = try authedUser.requireID()

        let listingIDs = try await Listing.query(on: req.db)
            .filter(\.$seller.$id == authedID)
            .all()
            .compactMap { $0.id }

        if listingIDs.isEmpty {
            return Page(items: [], metadata: .init(page: 1, per: 10, total: 0))
        }

        let statusParam = try? req.query.get(String.self, at: "status")
        let statusFilter = statusParam.flatMap { InquiryStatus(rawValue: $0) }

        var q = Inquiry.query(on: req.db).filter(\.$listing.$id ~~ listingIDs)
        if let s = statusFilter { q = q.filter(\.$status == s) }

        return try await q.paginate(for: req)
    }

    // =========================
    // Auth
    // =========================
    struct RegisterRequest: Content {
        let name: String
        let email: String
        let phone: String
        let password: String
        let isSeller: Bool?
        let fromVietnam: Bool?
        let country: String?
    }

    struct LoginRequest: Content {
        let email: String
        let password: String
    }

    struct TokenResponse: Content {
        let token: String
        let isSeller: Bool
        let isAdmin: Bool
        let name: String
    }

    api.post("auth", "register") { req async throws -> TokenResponse in
        let body = try req.content.decode(RegisterRequest.self)
        let email = body.email.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()

        if try await User.query(on: req.db).filter(\.$email == email).first() != nil {
            throw Abort(.badRequest, reason: "Email already in use")
        }
        if try await User.query(on: req.db).filter(\.$phone == body.phone).first() != nil {
            throw Abort(.badRequest, reason: "Phone already in use")
        }

        let hash = try Bcrypt.hash(body.password)

        let originCountry: String = {
            if body.fromVietnam == true { return "Vietnam" }
            let c = (body.country ?? "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return c.isEmpty ? "" : c
        }()

        let user = User(
            name: body.name,
            email: email,
            passwordHash: hash,
            phone: body.phone,
            isSeller: body.isSeller ?? false
        )
        user.originCountry = originCountry
        try await user.save(on: req.db)

        let payload = AuthPayload(
            sub: .init(value: try user.requireID().uuidString),
            exp: .init(value: .init(timeIntervalSinceNow: 3600))
        )
        let token = try req.jwt.sign(payload)
        return TokenResponse(
            token: token,
            isSeller: user.isSeller,
            isAdmin: user.isAdmin,
            name: user.name
        )
    }

    api.post("auth", "login") { req async throws -> TokenResponse in
        do {
            let body = try req.content.decode(LoginRequest.self)

            guard let user = try await User.query(on: req.db)
                .filter(\.$email == body.email)
                .first()
            else { throw Abort(.unauthorized, reason: "Invalid email or password") }

            guard try Bcrypt.verify(body.password, created: user.passwordHash) else {
                throw Abort(.unauthorized, reason: "Invalid email or password")
            }

            let payload = AuthPayload(
                sub: .init(value: try user.requireID().uuidString),
                exp: .init(value: .init(timeIntervalSinceNow: 3600))
            )
            let token = try req.jwt.sign(payload)
            return TokenResponse(
                token: token,
                isSeller: user.isSeller,
                isAdmin: user.isAdmin,
                name: user.name
            )
        } catch {
            req.logger.error("LOGIN FAILED: \(String(reflecting: error))")
            throw error
        }
    }

    // ===== Profile (protected) =====
    struct MeDTO: Content {
        let id: UUID
        let name: String
        let email: String
        let phone: String
        let isSeller: Bool
        let isAdmin: Bool
        let originCountry: String
    }

    protected.get("me") { req async throws -> MeDTO in
        let u = try req.auth.require(User.self)
        return MeDTO(
            id: try u.requireID(),
            name: u.name,
            email: u.email,
            phone: u.phone,
            isSeller: u.isSeller,
            isAdmin: u.isAdmin,
            originCountry: u.originCountry
        )
    }

    struct UpdateMeReq: Content {
        var name: String?
        var email: String?
        var phone: String?
        var currentPassword: String?
        var newPassword: String?
    }

    protected.patch("me") { req async throws -> MeDTO in
        let u = try req.auth.require(User.self)
        var body = try req.content.decode(UpdateMeReq.self)

        if let newEmail = body.email?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased(),
           newEmail != u.email {
            if try await User.query(on: req.db).filter(\.$email == newEmail).first() != nil {
                throw Abort(.badRequest, reason: "Email already in use")
            }
            u.email = newEmail
        }

        if let n = body.name { u.name = n }
        if let p = body.phone { u.phone = p }

        if let np = body.newPassword {
            guard let cp = body.currentPassword,
                  try Bcrypt.verify(cp, created: u.passwordHash)
            else {
                throw Abort(.unauthorized, reason: "Current password invalid")
            }
            u.passwordHash = try Bcrypt.hash(np)
        }

        try await u.save(on: req.db)

        return MeDTO(
            id: try u.requireID(),
            name: u.name,
            email: u.email,
            phone: u.phone,
            isSeller: u.isSeller,
            isAdmin: u.isAdmin,
            originCountry: u.originCountry
        )
    }

    protected.delete("me") { req async throws -> HTTPStatus in
        let u = try req.auth.require(User.self)
        let uid = try u.requireID()

        let listings = try await Listing.query(on: req.db)
            .filter(\.$seller.$id == uid)
            .all()

        for listing in listings {
            let listingID = try listing.requireID()
            try await Inquiry.query(on: req.db)
                .filter(\.$listing.$id == listingID)
                .delete()
            try await listing.delete(on: req.db)
        }

        try await u.delete(on: req.db)
        return .noContent
    }

    // =========================
    // Listing: update/delete (protected)
    // =========================
    struct UpdateListingReq: Content {
        var title: String?
        var desc: String?
        var price: Double?
        var minOrderQty: Int?
        var stock: Int?
        var imageUrls: [String]?
    }

    protected.patch("listings", ":id") { req async throws -> Listing in
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()

        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid listing id")
        }
        guard let listing = try await Listing.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Listing not found")
        }
        guard listing.$seller.id == userID else {
            req.logger.warning("PATCH listing denied: user \(userID) not owner of \(id)")
            throw Abort(.forbidden, reason: "You don't own this listing")
        }

        let body = try req.content.decode(UpdateListingReq.self)
        if let v = body.title       { listing.title = v }
        if let v = body.desc        { listing.desc = v }
        if let v = body.price       { listing.price = v }
        if let v = body.minOrderQty { listing.minOrderQty = v }
        if let v = body.stock       { listing.stock = v }
        if let v = body.imageUrls   { listing.imageUrls = v }

        try await listing.save(on: req.db)
        return listing
    }

    protected.delete("listings", ":id") { req async throws -> HTTPStatus in
        let user = try req.auth.require(User.self)
        let userID = try user.requireID()

        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid listing id")
        }
        guard let listing = try await Listing.find(id, on: req.db) else {
            throw Abort(.notFound, reason: "Listing not found")
        }
        guard try listing.$seller.id == userID else {
            req.logger.warning("DELETE listing denied: user \(userID) not owner of \(id)")
            throw Abort(.forbidden, reason: "You don't own this listing")
        }

        req.logger.info("Deleting listing \(id) by owner \(userID) ...")

        try await Inquiry.query(on: req.db)
            .filter(\.$listing.$id == id)
            .delete()

        try await listing.delete(on: req.db)

        req.logger.info("Deleted listing \(id) successfully")
        return .noContent
    }

    // ===== Contact (public) =====
    struct ContactReq: Content {
        let name: String
        let email: String
        let phone: String
        let company: String?
        let message: String
    }
    struct ContactRes: Content { let ok: Bool }

    api.post("contact") { req async throws -> ContactRes in
        let body = try req.content.decode(ContactReq.self)

        // normalize
        let name = body.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = body.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let phone = body.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let companyTrim = (body.company ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let company = companyTrim.isEmpty ? nil : companyTrim
        let message = body.message.trimmingCharacters(in: .whitespacesAndNewlines)

        let cm = ContactMessage(
            name: name,
            email: email,
            phone: phone,
            company: company,
            message: message,
            status: "new"
        )

        try await cm.save(on: req.db)
        return ContactRes(ok: true)
    }

    // ===== ربط مسارات الأخبار =====
    publicNewsRoutes(api)
    adminNewsRoutes(api)

    // استدعِ مسارات الأدمن الأخرى (Users / Contacts / …)
    adminRoutes(app)
}

// =========================
// Admin
// =========================
func adminRoutes(_ routes: any RoutesBuilder) {
    // مجموعة الأدمن (JWT + حارس أدمن)
    let admin = routes.grouped("api", "v1", "admin")
        .grouped(UserJWTAuthenticator())
        .grouped(AdminGuard())

    // DTO لواجهة الأدمن
    struct UserDTO: Content {
        var id: UUID
        var name: String
        var email: String
        var isSeller: Bool
        var isAdmin: Bool
        var listingsCount: Int
        var createdAt: Date?
    }

    // 1) إحصائيات عامة
    admin.get("stats") { req async throws -> [String: Int] in
        async let usersCount = User.query(on: req.db).count()
        async let sellersCount = User.query(on: req.db).filter(\.$isSeller == true).count()
        async let listingsCount = Listing.query(on: req.db).count()
        return [
            "users": try await usersCount,
            "sellers": try await sellersCount,
            "listings": try await listingsCount
        ]
    }

    // 1-b) إدارة رسائل "اتصل بنا"
    struct ContactDTO: Content {
        let id: UUID
        let name: String
        let email: String
        let phone: String
        let company: String?
        let message: String
        let status: String
        let respondedBy: String?
        let createdAt: Date?
    }

    // list with basic filters
    admin.get("contacts") { req async throws -> [ContactDTO] in
        struct Q: Content { var status: String? } // new | responded | all
        let q = try req.query.decode(Q.self)
        var builder = ContactMessage.query(on: req.db).sort(\.$createdAt, .descending)
        if let s = q.status?.lowercased(), s == "new" {
            builder = builder.filter(\.$status == "new")
        } else if let s = q.status?.lowercased(), s == "responded" {
            builder = builder.filter(\.$status == "responded")
        }
        let items = try await builder.all()
        return items.compactMap {
            guard let id = $0.id else { return nil }
            return ContactDTO(
                id: id, name: $0.name, email: $0.email, phone: $0.phone,
                company: $0.company, message: $0.message, status: $0.status,
                respondedBy: $0.respondedBy, createdAt: $0.createdAt
            )
        }
    }

    // mark responded
    struct RespondReq: Content { let respondedBy: String }
    admin.patch("contacts", ":id", "respond") { req async throws -> HTTPStatus in
        guard let id = req.parameters.get("id", as: UUID.self) else { throw Abort(.badRequest) }
        let body = try req.content.decode(RespondReq.self)
        guard let cm = try await ContactMessage.find(id, on: req.db) else { throw Abort(.notFound) }
        cm.status = "responded"
        cm.respondedBy = body.respondedBy
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .lowercased()
        try await cm.save(on: req.db)
        return .noContent
    }

    // 2) قائمة المستخدمين
    admin.get("users") { req async throws -> [UserDTO] in
        struct Query: Content {
            var role: String?
            var search: String?
            var page: Int?
            var limit: Int?
        }
        let q = try req.query.decode(Query.self)
        let page = max(q.page ?? 1, 1)
        let limit = min(max(q.limit ?? 20, 1), 100)

        var builder = User.query(on: req.db)
        if let role = q.role?.lowercased() {
            if role == "seller" { builder = builder.filter(\.$isSeller == true) }
            if role == "buyer"  { builder = builder.filter(\.$isSeller == false) }
        }
        if let s = q.search, !s.isEmpty {
            builder = builder.group(.or) {
                $0.filter(\.$name ~~ s)
                $0.filter(\.$email ~~ s)
            }
        }
        builder = builder.range((page - 1) * limit ..< page * limit)

        let users = try await builder.all()
        let userIds = users.compactMap { $0.id }

        // عدّاد منتجات كل مستخدم
        let counts = try await Listing.query(on: req.db)
            .filter(\.$seller.$id ~~ userIds)
            .all()
            .reduce(into: [UUID:Int]()) { dict, l in
                let uid = try! l.$seller.id
                dict[uid, default: 0] += 1
            }

        return try users.map { u in
            UserDTO(
                id: try u.requireID(),
                name: u.name,
                email: u.email,
                isSeller: u.isSeller,
                isAdmin: u.isAdmin,
                listingsCount: counts[try u.requireID()] ?? 0,
                createdAt: u.createdAt
            )
        }
    }

    // 3) حذف كل منتجات بائع
    admin.delete("users", ":userId", "listings") { req async throws -> HTTPStatus in
        guard let uid = req.parameters.get("userId", as: UUID.self) else { throw Abort(.badRequest) }
        try await Listing.query(on: req.db).filter(\.$seller.$id == uid).delete()
        return .noContent
    }

    // 4) حذف مستخدم (ومنتجاته)
    admin.delete("users", ":userId") { req async throws -> HTTPStatus in
        guard let uid = req.parameters.get("userId", as: UUID.self) else { throw Abort(.badRequest) }
        try await Listing.query(on: req.db).filter(\.$seller.$id == uid).delete()
        guard let user = try await User.find(uid, on: req.db) else { throw Abort(.notFound) }
        try await user.delete(on: req.db)
        return .noContent
    }

    // 5) ترقية/إزالة صلاحية الأدمن لمستخدم
    struct AdminToggleReq: Content { let isAdmin: Bool }
    admin.patch("users", ":userId", "admin") { req async throws -> HTTPStatus in
        guard let uid = req.parameters.get("userId", as: UUID.self) else { throw Abort(.badRequest) }
        let body = try req.content.decode(AdminToggleReq.self)
        guard let user = try await User.find(uid, on: req.db) else { throw Abort(.notFound) }
        user.isAdmin = body.isAdmin
        try await user.save(on: req.db)
        return .noContent
    }

    // 6) إنشاء مستخدم أدمن جديد
    struct CreateAdminReq: Content {
        let name: String
        let email: String
        let phone: String
        let password: String
    }
    admin.post("users", "admin") { req async throws -> UserDTO in
        let body = try req.content.decode(CreateAdminReq.self)

        if try await User.query(on: req.db).filter(\.$email == body.email).first() != nil {
            throw Abort(.badRequest, reason: "Email already in use")
        }
        if try await User.query(on: req.db).filter(\.$phone == body.phone).first() != nil {
            throw Abort(.badRequest, reason: "Phone already in use")
        }

        let u = User(
            name: body.name,
            email: body.email,
            passwordHash: try Bcrypt.hash(body.password),
            phone: body.phone,
            isSeller: false
        )
        u.isAdmin = true
        u.originCountry = ""
        try await u.save(on: req.db)

        return try UserDTO(
            id: u.requireID(),
            name: u.name,
            email: u.email,
            isSeller: u.isSeller,
            isAdmin: u.isAdmin,
            listingsCount: 0,
            createdAt: u.createdAt
        )
    }
}



// ========= Public News =========
func publicNewsRoutes(_ api: any RoutesBuilder) {
    api.get("news") { req async throws -> [NewsItem] in
        try await NewsItem.query(on: req.db)
            .filter(\.$isPublished == true)
            .sort(\.$eventDate, .descending)
            .all()
    }

    api.get("news", ":id") { req async throws -> NewsItem in
        guard let id = req.parameters.get("id", as: UUID.self),
              let item = try await NewsItem.find(id, on: req.db),
              item.isPublished
        else { throw Abort(.notFound) }
        return item
    }
}

// ========= Admin News (CRUD) =========
struct UpsertNewsReq: Content {
    var titleEn: String
    var titleVi: String
    var coverURL: String?
    var location: String?
    var bodyEn: String?
    var bodyVi: String?
    var eventDate: Date?
    var isPublished: Bool
}

func adminNewsRoutes(_ api: any RoutesBuilder) {
    let admin = api.grouped("admin").grouped(UserJWTAuthenticator(), AdminGuard())

    admin.get("news") { req async throws -> [NewsItem] in
        try await NewsItem.query(on: req.db)
            .sort(\.$createdAt, .descending)
            .all()
    }

    admin.post("news") { req async throws -> NewsItem in
        let b = try req.content.decode(UpsertNewsReq.self)
        let item = NewsItem(
            titleEn: b.titleEn, titleVi: b.titleVi,
            coverURL: b.coverURL, location: b.location,
            bodyEn: b.bodyEn, bodyVi: b.bodyVi,
            eventDate: b.eventDate, isPublished: b.isPublished
        )
        try await item.save(on: req.db)
        return item
    }

    admin.patch("news", ":id") { req async throws -> NewsItem in
        guard let id = req.parameters.get("id", as: UUID.self),
              let item = try await NewsItem.find(id, on: req.db)
        else { throw Abort(.notFound) }

        let b = try req.content.decode(UpsertNewsReq.self)
        item.titleEn = b.titleEn
        item.titleVi = b.titleVi
        item.coverURL = b.coverURL
        item.location = b.location
        item.bodyEn = b.bodyEn
        item.bodyVi = b.bodyVi
        item.eventDate = b.eventDate
        item.isPublished = b.isPublished
        try await item.save(on: req.db)
        return item
    }

    admin.delete("news", ":id") { req async throws -> HTTPStatus in
        guard let id = req.parameters.get("id", as: UUID.self),
              let item = try await NewsItem.find(id, on: req.db)
        else { throw Abort(.notFound) }
        try await item.delete(on: req.db)
        return .noContent
    }
}
