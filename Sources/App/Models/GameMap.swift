//
//  GameMap.swift
//  App
//
//  Created by IC on 16/01/2019.
//

import Foundation
import FluentMySQL
import Vapor
import Gzip

/// A single entry of a GameMap blueprint
final class GameMap: MySQLModel {
    /// The unique identifier
    var id: Int?
    
    ///Game seed
    var seed: String
    
    ///Tile number on the global planet map
    var tileId: Int
    ///Game unique identifier
    var gameId: UInt64
    var coverage: Int
    
    var width: Int
    var height: Int
    
    var originX: Int
    var originZ: Int
    var mapSize: Int
    
    var updatedAt: Date
    
    ///File name as it is stored in bucket
    var nameInBucket: String
    var biome: String
    
    var version: String
    
    /// Creates a new or updates existing game map blueprint
    init(blueprintData: Data, externalGameId: UInt64?) throws {
        
        guard let unzipped = try? blueprintData.gunzipped() else {
            throw RealRuinsError.malformedBlueprintGZIP()
        }
        
        guard let blueprint = try? XMLDocument.init(data: unzipped, options: []) else {
            throw RealRuinsError.malformedBlueprintXML("Can't init XML")
        }
        
        guard let root = blueprint.rootElement() else {
            throw RealRuinsError.malformedBlueprintXML("No root element found")
        }
        
        guard let blueprintWidth = Int(root.attribute(forName: "width")?.stringValue ?? ""),
            let blueprintHeight = Int(root.attribute(forName: "height")?.stringValue ?? "") else {
                throw RealRuinsError.malformedBlueprintXML("No height or width provided")
        }
        
        width = blueprintWidth
        height = blueprintHeight
        biome = root.attribute(forName: "biomeDef")?.stringValue ?? ""

        originX = Int(root.attribute(forName: "x")?.stringValue ?? "0") ?? 0
        originZ = Int(root.attribute(forName: "z")?.stringValue ?? "0") ?? 0
        mapSize = Int(root.attribute(forName: "mapSize")?.stringValue ?? "0") ?? 0


        version = root.attribute(forName: "version")?.stringValue ?? "1.0"
        
        guard let world = root.elements(forName: "world").first else {
            throw RealRuinsError.malformedBlueprintXML("No world tag found")
        }
        
        guard let blueprintSeed = world.attribute(forName: "seed")?.stringValue,
            let blueprintTileId = Int(world.attribute(forName: "tile")?.stringValue ?? "")  else {
            throw RealRuinsError.malformedBlueprintXML("No seed or tile tags found")
        }
        
        guard let blueprintGameId = UInt64(world.attribute(forName: "gameId")?.stringValue ?? "") ?? externalGameId else {
            throw RealRuinsError.malformedBlueprintXML("GameId is not provided either in XML or in request")
        }
        
        seed = blueprintSeed
        tileId = blueprintTileId
        gameId = blueprintGameId
        coverage = Int((Float(world.attribute(forName: "percentage")?.stringValue ?? "0") ?? 0) * 100)
        
        updatedAt = Date()
        nameInBucket = UUID.init().uuidString
    }
}

/// Allows `GameMap` to be used as a dynamic migration.
extension GameMap: Migration { }

/// Allows `GameMap` to be encoded to and decoded from HTTP messages.
extension GameMap: Content {
}

/// Allows `Todo` to be used as a dynamic parameter in route definitions.
extension GameMap: Parameter { }


/// Decompress and analyze blueprints
extension GameMap {
    
}
