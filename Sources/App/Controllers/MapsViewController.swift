//
//  WebMapsController.swift
//  App
//
//  Created by IC on 20/01/2019.
//

import Foundation
import Vapor
import Fluent
import FluentMySQL
import MySQL
import Storage

struct MapsContext: Encodable {
    let mapsList: [GameMap]
    let offset: Int
    let limit: Int
    let seed: String
    let title: String
}

struct SeedsListContext: Encodable {
    let seedsList: [Seed]
    let offset: Int
    let limit: Int
    let title: String
}

final class MapsViewController {

    func index(_ req: Request) throws -> Future<View> {
        return try req.view().render("index")
    }
    
    func viewMap(_ req: Request) throws -> Future<View> {
        return try req.view().render("mapView", [
            "mapId": req.parameters.next(Int.self)
            ])
    }

    func viewRandomMap(_ req: Request) throws -> Future<View> {
        return GameMap
            .query(on: req)
            .sort(MySQLOrderBy.orderBy(MySQLExpression.function("RAND"), MySQLDirection.ascending))
            .range(...1)
            .first().flatMap({ (gameMap) -> Future<View> in
                return try req.view().render("mapView", [
                    "mapId": gameMap?.id ?? 0
                    ])
            })
    }
    
    func viewStats(_ req: Request) throws -> Future<View> {
        return req.withPooledConnection(to: .mysql) { (conn) throws -> Future<Int> in
            return conn.raw("SELECT COUNT(*) AS num FROM GameMap").first().map({ (response : [MySQLColumn:MySQLData]?) -> Int in
                return try response?.firstValue(forColumn: "num")?.decode(Int.self) ?? 0
            })
            }.flatMap({ (count) -> Future<View> in
                return try req.view().render("stats", [
                    "total": "\(count)"
                    ])
            })
    }

    func withSeed(_ req: Request) throws -> Future<View> {
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
                    if mapSize != -1 {
                        result = result.filter(\.mapSize == mapSize)
                    }
                }
                
                if let coverage = filter?.coverage {
                    if coverage != -1 {
                        result = result.filter(\.coverage == coverage)
                    }
                }

                return result
                    .sort(\.id, MySQLDirection.ascending)
                    .range(offset..<offset+limit)
                    .all().flatMap({ (maps) -> Future<View> in
                        return try req.view().render("mapslist", MapsContext(mapsList: maps, offset: offset, limit: limit, seed: seed, title: "Maps list for seed '\(seed)' from \(offset) to \(offset + maps.count)"))
                    })
            } else {
                throw RealRuinsError.invalidParameters("No seed provided")
            }
    }

    func topSeeds(_ req: Request) throws -> Future<View> {
        return try MapsController().topSeeds(req).flatMap({ (seeds) throws -> EventLoopFuture<View> in
            let limitObj = try? req.query.decode(Limit.self)
            let offset = limitObj?.offset ?? 0
            let limit = limitObj?.limit ?? 50
            
            return try req.view().render("seedslist", SeedsListContext(seedsList: seeds, offset: offset, limit: limit, title: "Top seeds list from \(offset) to \(offset + seeds.count)"))
        })
    }
}
