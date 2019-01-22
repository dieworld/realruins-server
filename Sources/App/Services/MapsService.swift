//
//  MapsService.swift
//  App
//
//  Created by IC on 22/01/2019.
//

import Foundation
import Vapor
import Fluent
import FluentMySQL
import MySQL
import Storage


final class MapsService {
    
}

extension MapsService: ServiceType {
    /// See `ServiceType`.
    static var serviceSupports: [Any.Type] {
        return [MapsService.self]
    }
    
    /// See `ServiceType`.
    static func makeService(for worker: Container) throws -> MapsService {
        return MapsService()
    }
}
