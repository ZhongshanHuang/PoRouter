//
//  UIApplication+CurrentKeyWindow.swift
//  PoOrientationManager
//
//  Created by HzS on 2024/1/11.
//

import UIKit

extension UIApplication {
    var poCurrentkeyWindow: UIWindow? {
        if #available(iOS 15.0, *) {
            return self.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }.first?.keyWindow
        } else if #available(iOS 13.0, *) {
            return self.connectedScenes
                .filter { $0.activationState == .foregroundActive }
                .compactMap { $0 as? UIWindowScene }.first?.windows
                .filter { $0.isKeyWindow }.first
        } else {
            return UIApplication.shared.keyWindow
        }
        
    }
}
