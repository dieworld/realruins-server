import FluentMySQL
import Vapor
import Leaf
import Storage

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {

    /// Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    /// Leaf provider for web functionality
    try services.register(LeafProvider())

    let corsConfig = CORSMiddleware.Configuration.init(allowedOrigin: .all, allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH], allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith])
    let corsMiddleware = CORSMiddleware(configuration: corsConfig)
    
    let loggerMiddleware = Logger()
    loggerMiddleware.initialize()

    /// Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    middlewares.use(corsMiddleware)
    middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    middlewares.use(loggerMiddleware)
    services.register(middlewares)


    // Configure Leaf
    config.prefer(LeafRenderer.self, for: ViewRenderer.self)

    // Configure a MySQL database

    try services.register(FluentMySQLProvider())

    let mysql = MySQLDatabase(config: MySQLDatabaseConfig(hostname: "localhost", port: 3306, username: "realruins", password: DatabasePassword, database: "realruins", capabilities: MySQLCapabilities.default, characterSet: MySQLCharacterSet.utf8_general_ci, transport: MySQLTransportConfig.cleartext))
    

    /// Register the configured SQLite database to the database config.
    var databases = DatabasesConfig()
    databases.add(database: mysql, as: .mysql)
    services.register(databases)
    
    GameMap.defaultDatabase = .mysql
    Vote.defaultDatabase = .mysql

    /// Register S3 service
    let driver = try S3Driver(
        bucket: "realruinsv2",
        host: "sfo2.digitaloceanspaces.com",
        accessKey: S3ApiKey,
        secretKey: S3ApiSecret,
        region: "sfo2",
        pathTemplate: "/#file"
    )
    services.register(driver, as: NetworkDriver.self)
    
    services.register(MapsService.self)
    
    /// Configure migrations
 //   var migrations = MigrationConfig()
//    migrations.add(model: Todo.self, database: .sqlite)
 //   services.register(migrations)

}
