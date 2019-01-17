//
//  GameMap.swift
//  App
//
//  Created by IC on 16/01/2019.
//

import Foundation
import FluentMySQL
import Vapor
import NIO

/// A single entry of a GameMap blueprint
final class GameMap: MySQLModel {
    /// The unique identifier
    var id: Int?
    
    ///Game seed
    var seed: String
    
    ///Tile number on the global planet map
    var tileId: Int
    ///Game unique identifier
    var gameId: Int
    
    var width: Int
    var height: Int
    
    var updatedAt: Date
    
    ///File name as it is stored in bucket
    var nameInBucket: String
    
    /// Creates a new or updates existing game map blueprint
    init(blueprintData: Data) {
        seed = "n/a"
        tileId = Int.random(in: 0...10)
        gameId = Int.random(in: 0...10)
        width = 0
        height = 0
        updatedAt = Date()
        nameInBucket = "fish.txt"
    }
}

/// Allows `GameMap` to be used as a dynamic migration.
extension GameMap: Migration { }

/// Allows `GameMap` to be encoded to and decoded from HTTP messages.
extension GameMap: Content {
    public static func decode(from req: Request) throws -> Future<GameMap> {
        return try req.content.decode(Data.self).map { (data) -> (GameMap) in
            let content = GameMap.init(blueprintData: Data())
            return content
        }
    }
    
    public static func decode(from res: Response, for req: Request) throws -> Future<GameMap> {
        let content = try res.content.decode(GameMap.self)
        return content
    }
}
/// Allows `Todo` to be used as a dynamic parameter in route definitions.
extension GameMap: Parameter { }
