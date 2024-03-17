//
//  File.swift
//  
//
//  Created by HzS on 2024/3/17.
//

import Foundation

public protocol PatternConvertible {
    var asPattern: String { get }
}

extension String: PatternConvertible {
    public var asPattern: String {
        self
    }
}
