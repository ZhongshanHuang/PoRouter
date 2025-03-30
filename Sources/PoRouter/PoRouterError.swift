//
//  File.swift
//  
//
//  Created by HzS on 2024/1/28.
//

import Foundation

public enum PoRouterError: Error {
    case noMatchPattern(url: String)
    case interrupt(url: String)
    case noPresentBase(url: String)
    case noPushBase(url: String)
}
