//
//  Vote.swift
//  App
//
//  Created by IC on 22/01/2019.
//

import Foundation

import FluentMySQL
import Vapor
import Gzip

/// A single entry of a GameMap blueprint
final class Vote: MySQLModel {
    /// The unique identifier
    var id: Int?
    var mapId: Int

    var ip: String
    var voteType: Int
    
    init(mapId: Int, ip: String, voteType: Int) {
        self.mapId = mapId
        self.ip = ip
        self.voteType = voteType
    }
}
