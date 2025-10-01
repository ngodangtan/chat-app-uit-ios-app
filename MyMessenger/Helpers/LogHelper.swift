//
//  LogHelper.swift
//  MyMessenger
//
//  Created by Tan Ngo Dang on 1/10/25.
//

import Foundation

struct LogHelper {
    func logRequest(_ req: URLRequest, body: Data?) {
        var log = "\n========= 📤 REQUEST =========\n"
        log += "\(req.httpMethod ?? "GET") \(req.url?.absoluteString ?? "")\n"
        if let headers = req.allHTTPHeaderFields, !headers.isEmpty {
            log += "Headers:\n"
            headers.forEach { k, v in log += "  \(k): \(v)\n" }
        }
        if let body = body, !body.isEmpty {
            let bodyStr = String(data: body, encoding: .utf8) ?? "<non-utf8 body>"
            log += "Body:\n\(bodyStr)\n"
        }
        log += "==============================\n"
        print(log)
    }
    
    func logResponse(url: URL?, status: Int, data: Data?) {
        var log = "\n========= 📥 RESPONSE ========\n"
        log += "URL: \(url?.absoluteString ?? "")\n"
        log += "Status: \(status)\n"
        if let data = data, !data.isEmpty {
            let raw = String(data: data, encoding: .utf8) ?? "<non-utf8 data>"
            log += "Raw JSON:\n\(raw)\n"
        } else {
            log += "Raw JSON: <empty>\n"
        }
        log += "==============================\n"
        print(log)
    }
}
