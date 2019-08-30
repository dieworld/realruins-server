//
//  Logger.swift
//  App
//
//  Created by IC on 30/08/2019.
//

import Foundation
import Vapor

class Logger: Middleware {
    
    var logFolderPath: String = "/var/log/RRServer"
    var filenameFormatter: DateFormatter = DateFormatter()
    var logLineFormatter: DateFormatter = DateFormatter()

    func initialize() {
        if !FileManager.default.fileExists(atPath: logFolderPath) {
            try? FileManager.default.createDirectory(atPath: logFolderPath, withIntermediateDirectories: true, attributes: nil)
        }
        
        filenameFormatter.dateFormat = "yyyy-MM-dd"
        logLineFormatter.dateFormat = "HH:mm:ss.SSS"
    }
    
    func respond(to request: Request, chainingTo next: Responder) throws -> EventLoopFuture<Response> {
        print("\(request)")
        
        let logLine = "\(request.http.method) \(request.http.urlString)"
        writeLog(line: logLine)
        
        return try next.respond(to: request)
    }
    
    func writeLog(line: String) {
        let date = Date()
        let dateString = filenameFormatter.string(from: date)
        let fileURL = URL(fileURLWithPath: logFolderPath).appendingPathComponent("log-" + dateString + ".log")
        
        let logDate = logLineFormatter.string(from: date)
        let logLine = "[\(logDate)]: \(line)\r\n"
        let logData = logLine.data(using: .utf8)

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }
        
        if let fileHandle = try? FileHandle(forWritingTo: fileURL), let logData = logData {
            fileHandle.seekToEndOfFile()
            fileHandle.write(logData)
            fileHandle.closeFile()
        }

    }
    
    
}
