//
//  File.swift
//  
//
//  Created by HzS on 2024/1/24.
//

import UIKit

public protocol PoRouterableComponent: UIViewController {
    static var routerPattern: String { get }
    static func routeComponent(with params: Parameters?, ctx: PoRouter.Context?) -> PoRouterableComponent
}

public protocol PoRouterableComponentMap: CaseIterable {
    var pattern: PoRouter.Pattern { get }
    var component: PoRouterableComponent.Type { get }
}
