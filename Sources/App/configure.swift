
import Vapor

public func configure(_ app: Application) throws {
    
    app.botService = .init(pravdaService: app.pravdaService)
}
