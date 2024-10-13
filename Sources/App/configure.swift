import Leaf
import Vapor

// configures your application
public func configure(_ app: Application) async throws {
    // uncomment to serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    if let port = Environment.get("PORT").flatMap(Int.init) {
           app.http.server.configuration.port = port
       }
    app.views.use(.leaf)
    app.routes.defaultMaxBodySize = "10mb" // Adjust the size as needed
    // register routes
    try routes(app)
}
