//
//  UIViewController+CurrentViewController.swift
//  PoOrientationManager
//
//  Created by HzS on 2024/1/11.
//

import UIKit

extension UIViewController {
    
    static var poCurrentViewController: UIViewController? {
        UIViewController.topViewController(of: UIApplication.shared.poCurrentkeyWindow?.rootViewController)
    }
    
    private static func topViewController(of viewController: UIViewController?) -> UIViewController? {
        if let vc = viewController?.presentedViewController {
            return topViewController(of: vc)
        } else if let splitVC = viewController as? UISplitViewController {
            if splitVC.viewControllers.isEmpty {
                return viewController
            } else {
                return topViewController(of: splitVC.viewControllers.last)
            }
        } else if let naviVC = viewController as? UINavigationController {
            if naviVC.viewControllers.isEmpty {
                return viewController
            } else {
                return topViewController(of: naviVC.topViewController)
            }
        } else if let tabBarVC = viewController as? UITabBarController {
            if tabBarVC.viewControllers?.isEmpty == false {
                return topViewController(of: tabBarVC.selectedViewController)
            } else {
                return viewController
            }
        } else {
            return viewController
        }
    }
    
}

