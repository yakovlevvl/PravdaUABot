
import FluentPostgresDriver
import Vapor

public func configure(_ app: Application) throws {
    
//    if var config = Environment.get("DATABASE_URL")
//        .flatMap(URL.init)
//        .flatMap(PostgresConfiguration.init) {
//        config.tlsConfiguration = .forClient(
//            certificateVerification: .none)
//        app.databases.use(.postgres(
//            configuration: config
//        ), as: .psql)
//    }
    
    
    try routes(app)
    
    app.botService = .init()
}
