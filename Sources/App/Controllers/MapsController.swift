//
//  MapsController.swift
//  App
//
//  Created by IC on 16/01/2019.
//

import Vapor
import Fluent
import FluentMySQL
import MySQL
import Storage

struct GameId: Content {
    let gameId: String?
}

struct Limit: Content {
    let limit: Int?
}


struct GameCell: Content {
    var terrain: GameObject?
    var objects: [GameObject] = []
}

struct GameObject: Content {
    let def: String
    let stuffDef: String?
    let artDesc: String?
}

struct Seed: Content {
    let seed: String
    let num: Int
}

/// Controls basic CRUD operations on `Map`s.
final class MapsController {
    /// Returns a list of all `Map`s.
    func index(_ req: Request) throws -> Future<[GameMap]> {
        return GameMap.query(on: req).all()
    }
    
    func random(_ req: Request) throws -> Future<[GameMap]> {
        return GameMap
            .query(on: req)
            .sort(MySQLOrderBy.orderBy(MySQLExpression.function("RAND"), MySQLDirection.ascending))
            .range(..<50)
            .all()
    }
    
    func withSeed(_ req: Request) throws -> Future<[GameMap]> {
        if let seed = try? req.parameters.next(String.self) {
            let seedDecoded = seed.removingPercentEncoding ?? seed
            return GameMap
                .query(on: req)
                .filter(\.seed == seedDecoded)
                .sort(MySQLOrderBy.orderBy(MySQLExpression.function("RAND"), MySQLDirection.ascending))
                .range(..<200)
                .all()
        } else {
            throw RealRuinsError.invalidParameters("No seed provided")
        }
    }
    
    func topSeeds(_ req: Request) throws -> Future<[Seed]> {
        let limitObj = try? req.query.decode(Limit.self)
        let limit = limitObj?.limit ?? 50
        
        return req.withPooledConnection(to: .mysql) { conn throws -> Future<[Seed]> in
            return conn.raw("SELECT seed, COUNT(*) AS num FROM GameMap GROUP BY seed ORDER BY num DESC LIMIT \(limit)")
                .all(decoding: Seed.self)
            }
    }
    
    func json(_ req: Request) throws -> Future<[[GameCell]]> {
        
        
        
        guard let mapId = try? req.parameters.next(Int.self) else {
            throw RealRuinsError.invalidParameters("No ID provided")
        }
        
        return GameMap
            .find(mapId, on: req)
            .flatMap(to: Response.self, { (gameMap) throws -> Future<Response> in
                if let name = gameMap?.nameInBucket {
                    let fullName = "https://realruinsv2.sfo2.digitaloceanspaces.com" + "/" + name + ".bp"
                    return try req.client().get(fullName)
                } else {
                    return req.eventLoop.newFailedFuture(error: RealRuinsError.invalidParameters("not found"))
                }
            }).map(to: [[GameCell]].self, { (response) throws -> [[GameCell]] in
                guard let blueprintData = response.http.body.data else {
                    throw RealRuinsError.noData()
                }
                
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
                
                var cells: [[GameCell]] = [[]]
                for y in 0..<blueprintHeight {
                    cells.append(Array())
                    for _ in 0..<blueprintWidth {
                        cells[y].append(GameCell.init())
                    }
                }
                
                for node in root.elements(forName: "cell") {
                    if let nodeX = Int(node.attribute(forName: "x")?.stringValue ?? ""),
                        let nodeZ = Int(node.attribute(forName: "z")?.stringValue ?? "") {
                        var gameCell = cells[nodeZ][nodeX]
                        if let terrainDef = node.elements(forName: "terrain").first?.attribute(forName: "def")?.stringValue {
                            gameCell.terrain = GameObject.init(def: terrainDef, stuffDef: nil, artDesc: nil)
                        }
                        
                        for item in node.elements(forName: "item") {
                            if let itemDef = item.attribute(forName: "def")?.stringValue {
                                let stuffDef = item.attribute(forName: "stuffDef")?.stringValue
                                gameCell.objects.append(GameObject(def: itemDef, stuffDef: stuffDef, artDesc: ""))
                            }
                        }
                        cells[nodeZ][nodeX] = gameCell
                    }
                }
                return cells
            })
    }
    
    /// Saves a decoded `GameMap` to the database.
    func create(_ req: Request) throws -> Future<GameMap> {
        guard let data = req.http.body.data else {
            return req.eventLoop.newFailedFuture(error: RealRuinsError.noData())
        }
        
        //on some reason it doesn't work with gameId as Int, so I have to use String
        let gameId = try? req.query.decode(GameId.self)
        let gameMap = try GameMap.init(blueprintData: data, externalGameId: UInt64(gameId?.gameId ?? ""))
        
        return GameMap.query(on: req)
            .filter(\.gameId == gameMap.gameId)
            .filter(\.tileId == gameMap.tileId)
            .first().flatMap { (storedMap) -> EventLoopFuture<GameMap> in
            
            if let storedMap = storedMap {
                /// Updating existing map
                storedMap.updatedAt = Date()
                storedMap.height = gameMap.height
                storedMap.width = gameMap.width
                return try Storage
                    .upload(bytes: data,
                            fileName: storedMap.nameInBucket,
                            fileExtension: "bp", mime: "application/octet-stream",
                            folder: nil, on: req)
                    .flatMap({ (result) -> EventLoopFuture<GameMap> in
                        return storedMap.update(on: req)
                    })

                
            } else {
                /// Creating a new map object
                let filename = UUID.init().uuidString;
                return try Storage
                    .upload(bytes: data,
                            fileName: filename,
                            fileExtension: "bp", mime: "application/octet-stream",
                            folder: nil, on: req)
                    .flatMap({ (result) -> EventLoopFuture<GameMap> in
                        gameMap.nameInBucket = filename
                        return gameMap.save(on: req)
                })
            }
        }
    }
    
    /// Deletes a parameterized `Todo`.
    func delete(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(GameMap.self).flatMap { gameMap in
            return gameMap.delete(on: req)
            }.transform(to: .ok)
    }
}
