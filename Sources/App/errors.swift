//
//  errors.swift
//  App
//
//  Created by IC on 17/01/2019.
//

import Foundation
import Vapor

struct RealRuinsError: Debuggable {
    
    public static let readableName = "RealRuins Error"
    
    var identifier: String
    var reason: String
    public var sourceLocation: SourceLocation?

    static func noData() -> RealRuinsError {
        return RealRuinsError.init(identifier: "No map data", reason: "Add map request did not contain map data attached in body")
    }
    
    static func malformedBlueprintGZIP() -> RealRuinsError {
        return RealRuinsError.init(identifier: "Can't decompress", reason: "Map body can not be decompressed")
    }
    
    static func malformedBlueprintXML(_ additional : String) -> RealRuinsError {
        return RealRuinsError.init(identifier: "Malformed map XML", reason: additional)
    }
    
    public init(
        identifier: String,
        reason: String,
        file: String = #file,
        function: String = #function,
        line: UInt = #line,
        column: UInt = #column
        ) {
        self.identifier = identifier
        self.reason = reason
        self.sourceLocation = .init(file: file, function: function, line: line, column: column, range: nil)
    }
    
}
