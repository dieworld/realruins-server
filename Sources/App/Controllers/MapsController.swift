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


/// Request structures
struct GameId: Content {
    let gameId: String?
}

struct Limit: Content {
    let limit: Int?
    let offset: Int?
}


struct MapFilter: Content {
    let mapSize: Int?
    let coverage: Int?
}


/// Response structures
// For map JSON request
struct GameCell: Content {
    var x: Int?
    var y: Int?
    var terrain: GameObject?
    var objects: [GameObject] = []
}

// For map JSON request
struct GameObject: Content {
    let def: String
    let stuffDef: String?
    let artDesc: String?
}

// For seed:count request
struct Seed: Content {
    let seed: String
    let num: Int
}

// Vote statistics
struct VoteStats: Content {
    let removeVotes: Int
    let promoteVotes: Int
}

struct Distribution: Content {
    let sizes: [Int]
    let coverages: [Int]
    let data: [[Int]]
}

/// Controls basic CRUD operations on `Map`s.
final class MapsController {
    /// Returns a list of all `Map`s.
    func index(_ req: Request) throws -> Future<[GameMap]> {
        let limitObj = try? req.query.decode(Limit.self)
        let limit = limitObj?.limit ?? 50
        let offset = limitObj?.offset ?? 0
        
        return GameMap.query(on: req).range(offset..<(offset+limit)).all()
    }
    
    func random(_ req: Request) throws -> Future<[GameMap]> {
        let limitObj = try? req.query.decode(Limit.self)
        let limit = limitObj?.limit ?? 50
        return GameMap
            .query(on: req)
            .sort(MySQLOrderBy.orderBy(MySQLExpression.function("RAND"), MySQLDirection.ascending))
            .range(..<limit)
            .all()
    }
    
    func withSeed(_ req: Request) throws -> Future<[GameMap]> {
        if let seed = try? req.parameters.next(String.self) {
            let seedDecoded = seed.removingPercentEncoding ?? seed
  
            let limitObj = try? req.query.decode(Limit.self)
            let limit = limitObj?.limit ?? 50
            let offset = limitObj?.offset ?? 0
            let filter = try? req.query.decode(MapFilter.self)

            var result = GameMap
                .query(on: req)
                .filter(\.seed == seedDecoded)
            
            if let mapSize = filter?.mapSize {
                if (mapSize != -1) {
                    result = result.filter(\.mapSize == mapSize)
                }
            }
            
            if let coverage = filter?.coverage {
                if (coverage != -1) {
                    result = result.filter(\.coverage == coverage)
                }
            }
            
            return
                result
                .sort(MySQLOrderBy.orderBy(MySQLExpression.function("RAND"), MySQLDirection.ascending))
                .range(offset..<offset+limit)
                .all()
        } else {
            throw RealRuinsError.invalidParameters("No seed provided")
        }
    }
    
    func distribution(_ req: Request) throws -> Future<Distribution> {
        let coverages = [0, 5, 30, 50, 100, -1]
        let sizes = [0, 200, 225, 250, 275, 300, 325, 350, 400, -1]
        let seed = try req.parameters.next(String.self)
        
        return req.withPooledConnection(to: .mysql) { conn throws -> Future<[[MySQLColumn: MySQLData]]> in
            return conn.raw("SELECT coverage, mapSize, count(coverage) FROM GameMap WHERE seed=\"\(seed)\" GROUP BY coverage, mapSize").all()
            }.map(to: Distribution.self, { (result) -> Distribution in
                var data = Array<Array<Int>>(repeating: Array<Int>(repeating: 0, count: sizes.count),
                                             count: coverages.count)
                
                let coverageCol = MySQLColumn(table: "GameMap", name: "coverage")
                let sizeCol = MySQLColumn(table: "GameMap", name: "mapSize")
                let countCol = MySQLColumn(name: "count(coverage)")
                
                for row in result {
                    let coverage = try row[coverageCol]?.integer(Int32.self) ?? 0
                    let size = try row[sizeCol]?.integer(Int32.self) ?? 0
                    let count: Int32 = ((try row[countCol]?.integer(Int32.self)) ?? 0)
                    
                    let coverageIndex = coverages.index(of: Int(coverage)) ?? coverages.count - 1
                    let sizeIndex = sizes.index(of: Int(size)) ?? sizes.count - 1
                    data[coverageIndex][sizeIndex] += Int(count)
                }
                
                let distr = Distribution(sizes: sizes, coverages: coverages, data: data)
                return distr
            })
        
    }
    
    func topSeeds(_ req: Request) throws -> Future<[Seed]> {
        let limitObj = try? req.query.decode(Limit.self)
        var limit = limitObj?.limit ?? 50
        let offset = limitObj?.offset ?? 0
        if (limit > 1000) {limit = 1000}
        
        return req.withPooledConnection(to: .mysql) { conn throws -> Future<[Seed]> in
            return conn.raw("SELECT seed, COUNT(*) AS num FROM GameMap GROUP BY seed ORDER BY num DESC LIMIT \(limit) OFFSET \(offset)")
                .all(decoding: Seed.self)
            }
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
    
    func voteForRemoval(_ req: Request) throws ->  Future<HTTPStatus> {
        return try self.vote(req, voteType: 500)
    }
    
    func voteForPromotion(_ req: Request) throws ->  Future<HTTPStatus> {
        return try self.vote(req, voteType: 100)
    }
    
    func vote(_ req: Request, voteType: Int) throws -> Future<HTTPStatus> {
        guard let ip = req.http.remotePeer.hostname,
            let mapId = try? req.parameters.next(Int.self) else {
                return req.eventLoop.newSucceededFuture(result: HTTPStatus.badRequest)
        }
        
        return Vote
            .query(on: req)
            .filter(\.mapId == mapId)
            .filter(\.ip == ip)
            .filter(\.voteType == voteType)
            .first()
            .flatMap({ (vote) -> EventLoopFuture<HTTPStatus> in
                if (vote != nil) {
                    return req.eventLoop.newSucceededFuture(result: HTTPStatus.alreadyReported)
                } else {
                    let newVote = Vote(mapId: mapId, ip: ip, voteType: voteType)
                    return newVote.save(on: req).transform(to: .ok)
                }
            })
    }
    
    func delete(_ req: Request) throws -> Future<HTTPStatus> {
        return try req.parameters.next(GameMap.self).flatMap { gameMap in
            return gameMap.delete(on: req)
            }.transform(to: .ok)
    }
}

/// Returning map data in json format
extension MapsController {
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
    
    func json2(_ req: Request) throws -> Future<[GameCell]> {
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
            }).map(to: [GameCell].self, { (response) throws -> [GameCell] in
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

                var cells: [GameCell] = []
                
                for node in root.elements(forName: "cell") {
                    if let nodeX = Int(node.attribute(forName: "x")?.stringValue ?? ""),
                       let nodeZ = Int(node.attribute(forName: "z")?.stringValue ?? "") {
                        var gameCell = GameCell()
                        gameCell.x = nodeX
                        gameCell.y = nodeZ
                        
                        if let terrainDef = node.elements(forName: "terrain").first?.attribute(forName: "def")?.stringValue {
                            gameCell.terrain = GameObject.init(def: terrainDef, stuffDef: nil, artDesc: nil)
                        }
                        
                        for item in node.elements(forName: "item") {
                            if let itemDef = item.attribute(forName: "def")?.stringValue {
                                let stuffDef = item.attribute(forName: "stuffDef")?.stringValue
                                gameCell.objects.append(GameObject(def: itemDef, stuffDef: stuffDef, artDesc: ""))
                            }
                        }
                        cells.append(gameCell)
                    }
                }
                return cells
            })
    }
    
}
