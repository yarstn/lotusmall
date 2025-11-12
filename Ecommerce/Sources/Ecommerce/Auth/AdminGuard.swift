import Vapor

struct AdminGuard: AsyncMiddleware {
    func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let user = try req.auth.require(User.self)
        guard user.isAdmin == true else { throw Abort(.forbidden, reason: "Admins only") }
        return try await next.respond(to: req)
    }
}
