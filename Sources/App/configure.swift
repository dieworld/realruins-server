import FluentSQLite
import FluentMySQL
import Vapor
import Storage

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    /// Register providers first
    try services.register(FluentSQLiteProvider())

    /// Register routes to the router
    let router = EngineRouter.default()
    try routes(router)
    services.register(router, as: Router.self)

    /// Register middleware
    var middlewares = MiddlewareConfig() // Create _empty_ middleware config
    /// middlewares.use(FileMiddleware.self) // Serves files from `Public/` directory
    middlewares.use(ErrorMiddleware.self) // Catches errors and converts to HTTP response
    services.register(middlewares)

    // Configure a SQLite database
    let sqlite = try SQLiteDatabase(storage: .memory)

    // Configure a MySQL database
    let mysql = MySQLDatabase(config: MySQLDatabaseConfig(hostname: "localhost", port: 3306, username: "realruins", password: DatabasePassword, database: "realruins", capabilities: MySQLCapabilities.default, characterSet: MySQLCharacterSet.utf8_general_ci, transport: MySQLTransportConfig.cleartext))
    

    /// Register the configured SQLite database to the database config.
    var databases = DatabasesConfig()
    databases.add(database: mysql, as: .mysql)
    databases.add(database: sqlite, as: .sqlite)
    services.register(databases)
    
    GameMap.defaultDatabase = .mysql
    
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
    


    /// Configure migrations
    var migrations = MigrationConfig()
    migrations.add(model: Todo.self, database: .sqlite)
    services.register(migrations)

}
