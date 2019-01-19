//
//  MapsController.swift
//  App
//
//  Created by IC on 16/01/2019.
//

import Vapor
import Fluent
import FluentMySQL
import Storage

struct GameId: Content {
    let gameId: String?
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
    
    /// Saves a decoded `Todo` to the database.
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
