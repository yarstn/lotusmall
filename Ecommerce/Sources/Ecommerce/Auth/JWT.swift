import Vapor
import JWT
import Fluent

// حمولة التوكن
struct AuthPayload: JWTPayload {
    var sub: SubjectClaim
    var exp: ExpirationClaim
    func verify(using signer: JWTSigner) throws { try exp.verifyNotExpired() }
}

// مصادِق JWT: يقرأ التوكن ويحمل المستخدم في req.auth
struct UserJWTAuthenticator: AsyncJWTAuthenticator {
    typealias Payload = AuthPayload

    func authenticate(jwt: AuthPayload, for req: Request) async throws {
        guard let id = UUID(uuidString: jwt.sub.value) else { return }
        if let user = try await User.find(id, on: req.db) {
            req.auth.login(user)
        }
    }
}

