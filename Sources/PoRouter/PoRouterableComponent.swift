//
//  File.swift
//  
//
//  Created by HzS on 2024/1/24.
//

import UIKit

public enum PoRouterableResult {
    case component(_ component: PoRouterableComponent, _ type: PoRouter.RouteType = .push(animated: true))
    case action(() -> Void)
}

public protocol PoRouterableComponent : UIViewController {
    static var routerPattern: any PatternConvertible { get }
    static func routeComponent(with params: Parameters?, ctx: PoRouter.Context?) -> PoRouterableResult
}

public protocol PoRouterableComponentMap: CaseIterable {
    var asPattern: String { get }
    var component: any PoRouterableComponent.Type { get }
}

extension PoRouterableComponentMap {
    public var asPattern: String {
        component.routerPattern.asPattern
    }
}


