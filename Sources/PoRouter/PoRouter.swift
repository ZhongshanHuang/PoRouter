// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit

enum Constant {
    static let appleBundleSuffix = "com.apple"
    static let saveRegisterVersionKey = "saveRegisterVersionKey"
    static let saveRegisterCacheKey = "saveRegisterCacheKey"
}

extension PoRouter {
    public typealias Context = Any
    public typealias Pattern = String
    
    public enum RouteType {
        case push
        case present
    }
}

public final class PoRouter {
    public static let shared = PoRouter()
    public private(set) var scheme: String!
    
    private var patternMatcher: [String: PoRouterableComponent.Type] = [:]
    private var errorHandler: ((PoRouterError) -> Void)?
    private init() {}
        
    public func config(with scheme: String) {
        PoRouter.shared.scheme = scheme.hasSuffix("://") ? scheme : scheme + "://"
    }
    
    public func configGlobalErrorHandler(_ errorHandler: @escaping (PoRouterError) -> Void) {
        self.errorHandler = errorHandler
    }
    
    // MARK: - Register
    public func register<Map: PoRouterableComponentMap>(map: Map.Type) {
        map.allCases.forEach { mapItem in
            register(mapItem.pattern, for: mapItem.component)
        }
    }
    
    public func register(_ pattern: Pattern, for routeComponent: PoRouterableComponent.Type) {
        patternMatcher[routeComponent.routerPattern] = routeComponent.self
    }
    
    /// 自动将所有符合PoRouterableComponent和UIViewController注册
    public func autoRegisterAll() {
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
        
        #if DEBUG
        let start = CFAbsoluteTimeGetCurrent()
        defer { let end = CFAbsoluteTimeGetCurrent(); print("PoRouter auto register host time: \(end - start)") }
        #endif
        
        /// 版本没变，且存在缓存，则用缓存
        if let saveVersion = UserDefaults.standard.string(forKey: Constant.saveRegisterVersionKey),
           currentVersion == saveVersion,
            let cache = UserDefaults.standard.array(forKey: Constant.saveRegisterCacheKey) as? [String], !cache.isEmpty {
            for className in cache {
                guard let classItem = NSClassFromString(className) else { continue }
                if let routerableClass = classItem as? PoRouterableComponent.Type {
                    patternMatcher[routerableClass.routerPattern] = routerableClass
                }
            }
            return
        }
        
        guard let bundles = CFBundleGetAllBundles() as? [CFBundle] else { return }
        
        var cache = [String]()
        for bundle in bundles {
            if let identifier = CFBundleGetIdentifier(bundle) as? String {
                if identifier.hasPrefix(Constant.appleBundleSuffix) {
                    continue
                }
            }
            let executableURL = CFBundleCopyExecutableURL(bundle) as NSURL
            let imageURL = executableURL.fileSystemRepresentation
            let classCount = UnsafeMutablePointer<UInt32>.allocate(capacity: MemoryLayout<UInt32>.stride)
            guard let classNames = objc_copyClassNamesForImage(imageURL, classCount) else { continue }
            
            for idx in 0..<classCount.pointee {
                let className = String(cString: classNames[Int(idx)])
                guard let classItem = NSClassFromString(className) else { continue }
                
                if classItem is UIViewController.Type, let routerableClass = classItem as? PoRouterableComponent.Type {
                    var pattern = routerableClass.routerPattern
                    if scheme != nil, !pattern.hasPrefix(scheme) {
                        pattern = scheme + pattern
                    }
                    patternMatcher[pattern] = routerableClass
                    cache.append(className)
                }
            }
        }
        UserDefaults.standard.setValue(cache, forKey: Constant.saveRegisterCacheKey)
        UserDefaults.standard.setValue(currentVersion, forKey: Constant.saveRegisterVersionKey)
    }
    
    /// clear autoRegisterAll cache
    public func clearRegisterCache() {
        UserDefaults.standard.removeObject(forKey: Constant.saveRegisterCacheKey)
        UserDefaults.standard.removeObject(forKey: Constant.saveRegisterVersionKey)
    }
    
    // MARK: Route
    
    public func route(_ url: String, ctx: Context? = nil, type: RouteType = .push) throws {
        switch type {
        case .push:
            try push(url, ctx: ctx, from: nil, animated: true)
        case .present:
            try present(url, ctx: ctx, wrap: nil, from: nil, animated: true, completion: nil)
        }
    }
    
    public func push(_ url: String, ctx: Context? = nil, from: UINavigationController? = nil, animated: Bool = true) throws {
        do {
            let vc = try buildRouterableComponent(url: url, ctx: ctx)
            guard let navigationController = from ?? UIViewController.poCurrentViewController?.navigationController else {
                throw PoRouterError.noPushBase(url: url)
            }
            navigationController.pushViewController(vc, animated: animated)
        } catch let error as PoRouterError {
            errorHandler?(error)
            throw error
        }
    }
        
    public func present(_ url: String, ctx: Context? = nil, wrap: UINavigationController.Type? = nil, from: UIViewController? = nil, animated: Bool = true, completion: (() -> Void)? = nil) throws {
        do {
            var vc: UIViewController = try buildRouterableComponent(url: url, ctx: ctx)
            if let wrapType = wrap {
                vc = wrapType.init(rootViewController: vc)
            }

            guard let fromViewController = from ?? UIViewController.poCurrentViewController else {
                throw PoRouterError.noPresentBase(url: url)
            }
            
            fromViewController.present(vc, animated: animated, completion: completion)
        } catch let error as PoRouterError {
            errorHandler?(error)
            throw error
        }
    }
            
    // MARK: - Helper
    private func buildRouterableComponent(url: String, ctx: Context? = nil) throws -> PoRouterableComponent {
        var url = url
        if scheme != nil, !url.hasPrefix(scheme) {
            url = scheme + url
        }
        let urlComponents = url.components(separatedBy: "?")
        guard let routeComponent = patternMatcher[urlComponents[0]] else {
            throw PoRouterError.noMatchPattern(url: url)
        }
        
        var params: Parameters?
        if urlComponents.count == 2 { // has query
            params = extractForms(from: urlComponents[1])
        }
        
        return routeComponent.routeComponent(with: params, ctx: ctx)
    }
    
    private func extractForms(from query: String) -> Parameters {
        var result = Parameters()
        query.components(separatedBy: "&").forEach { (queryItem) in
            let queryItemComponent = queryItem.components(separatedBy: "=")
            if queryItemComponent.count == 2 {
                result.set(queryItemComponent[0], to: queryItemComponent[1])
            }
        }
        return result
    }

}

