import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import JWT

public func configure(_ app: Application) async throws {
    // ملفات الستاتيك (public/)
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // حجم البدي للرفع
    app.routes.defaultMaxBodySize = "20mb"

    // ===== قاعدة البيانات (PostgreSQL محلي) =====
    let dbHost = Environment.get("DATABASE_HOST") ?? "localhost"
    let dbPort = Environment.get("DATABASE_PORT").flatMap(Int.init) ?? SQLPostgresConfiguration.ianaPortNumber
    let dbUser = Environment.get("DATABASE_USERNAME") ?? "postgres"
    let dbPass = Environment.get("DATABASE_PASSWORD") ?? ""
    let dbName = Environment.get("DATABASE_NAME") ?? "ecommerce"

    // محلياً عطّل TLS لتفادي أخطاء NIOSSL
    let dbConfig = SQLPostgresConfiguration(
        hostname: dbHost,
        port: dbPort,
        username: dbUser,
        password: dbPass,
        database: dbName,
        tls: .disable
    )

    app.databases.use(.postgres(configuration: dbConfig), as: .psql)


    // ===== الهجرات =====
    app.migrations.add(CreateTodo())
    app.migrations.add(CreateUser())
    app.migrations.add(ChangePhoneType())
    app.migrations.add(CreateListing())
    app.migrations.add(CreateInquiry())
    app.migrations.add(AddOriginCountryToUser())
    app.migrations.add(AddIsAdminToUser()) // لحقل is_admin في User
    app.migrations.add(CreateContactMessage())
    app.migrations.add(CreateNewsItem())



    // CORS للفرونت على :3000 مع الكوكيز/التوكن
    let cors = CORSMiddleware.Configuration(
        allowedOrigin: .custom("http://localhost:3000"),
        allowedMethods: [.GET, .POST, .PUT, .PATCH, .DELETE, .OPTIONS],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent],
        allowCredentials: true
    )
    app.middleware.use(CORSMiddleware(configuration: cors))

    // أخطاء JSON واضحة (بدل HTML)
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    // JWT
    guard let jwtKey = Environment.get("JWT_SECRET") else {
        fatalError("❌ JWT_SECRET not set in environment variables.")
    }
    app.jwt.signers.use(.hs256(key: jwtKey))

    // (اختياري أثناء التطوير)
     try await app.autoMigrate()

    // التسجيل بالمسارات
    try routes(app)
    adminRoutes(app)
}
