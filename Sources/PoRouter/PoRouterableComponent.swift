//
//  File.swift
//  
//
//  Created by HzS on 2024/1/24.
//

import UIKit

public protocol PoRouterableComponent: UIViewController {
    static var routerPattern: any PatternConvertible { get }
    static func routeComponent(with params: Parameters?, ctx: PoRouter.Context?) -> PoRouterableComponent
}

public protocol PoRouterableComponentMap: CaseIterable {
    var routerPattern: any PatternConvertible { get }
    var component: any PoRouterableComponent.Type { get }
}

extension PoRouterableComponentMap {
    public var routerPattern: any PatternConvertible {
        component.routerPattern
    }
}


