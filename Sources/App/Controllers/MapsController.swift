//
//  MapsController.swift
//  App
//
//  Created by IC on 16/01/2019.
//

import Vapor
import Fluent
import FluentMySQL

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
    
    /// Saves a decoded `Todo` to the database.
    func create(_ req: Request) throws -> Future<GameMap> {
        guard let data = req.http.body.data else {
            return req.eventLoop.newFailedFuture(error: RealRuinsError.noData)
        }
        
        let gameMap = GameMap.init(blueprintData: data)
        return GameMap.query(on: req)
            .filter(\.gameId == gameMap.gameId)
            .filter(\.tileId == gameMap.tileId)
            .first().flatMap { (storedMap) -> EventLoopFuture<GameMap> in
            
            if let storedMap = storedMap {
                storedMap.updatedAt = Date()
                storedMap.height = gameMap.height
                storedMap.width = gameMap.width
                //save to S3
                return storedMap.update(on: req)
            } else {
                //save to S3
                return gameMap.save(on: req)
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
