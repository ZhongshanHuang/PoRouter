// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit

extension PoRouter {
    public typealias Context = [String: Any]
    
    public enum RouteType {
        case push(animated: Bool = true)
        case present(wrapper: UINavigationController.Type? = nil, modalPresentationStyle: UIModalPresentationStyle = .fullScreen,
                     animated: Bool = true)
    }
}

public final class PoRouter {
    public static let shared = PoRouter()
    public private(set) var scheme: String!
    
    private var patternMatcher: [String: PoRouterableComponent.Type] = [:]
    private var errorHandler: ((PoRouterError) -> Void)?
    private var interruptHandler: ((_ url: String, _ pattern: PatternConvertible, _ params: Parameters?, _ ctx: PoRouter.Context?) -> Bool)?
    private init() {}
        
    public func config(with scheme: String) {
        PoRouter.shared.scheme = scheme.hasSuffix("://") ? scheme : scheme + "://"
    }
    
    public func configGlobalErrorHandler(_ errorHandler: @escaping (PoRouterError) -> Void) {
        self.errorHandler = errorHandler
    }
    
    public func configGlobalInterruptHandler(_ interruptHandler: @escaping (_ url: String, _ pattern: PatternConvertible, _ params: Parameters?, _ ctx: PoRouter.Context?) -> Bool) {
        self.interruptHandler = interruptHandler
    }
    
    // MARK: - Register
    public func register<Map: PoRouterableComponentMap>(map: Map.Type) {
        map.allCases.forEach { mapItem in
            register(mapItem.component.routerPattern, for: mapItem.component)
        }
    }
    
    public func register(_ pattern: PatternConvertible, for routeComponent: PoRouterableComponent.Type) {
        var pattern = routeComponent.routerPattern.asPattern
        if scheme != nil, !pattern.hasPrefix(scheme) {
            pattern = scheme + pattern
        }
        patternMatcher[pattern] = routeComponent.self
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
                    patternMatcher[routerableClass.routerPattern.asPattern] = routerableClass
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
                    var pattern = routerableClass.routerPattern.asPattern
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
    
    public func matchPattern(_ pattern: String) -> Bool {
        patternMatcher.contains(where: { $0.value.routerPattern.asPattern == pattern })
    }
    
    // MARK: Route
    
    public func route(_ url: String, ctx: Context? = nil, type: RouteType? = nil) throws {
        do {
            let res = try buildRouterableResult(url: url, ctx: ctx)
            let current = UIViewController.poCurrentViewController
            if current?.isBeingDismissed == true || current?.navigationController?.isBeingDismissed == true {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                    try? self.handleRouterableResult(current: UIViewController.poCurrentViewController, result: res, url: url, type: type)
                })
                return
            }
            
            try handleRouterableResult(current: current, result: res, url: url, type: type)
        } catch let error as PoRouterError {
            errorHandler?(error)
            throw error
        }
    }
    
    // MARK: - Helper
    
    private func handleRouterableResult(current: UIViewController?, result: PoRouterableResult, url: String, type: RouteType? = nil) throws {
        switch result {
        case .component(let vc, let preferredRouteType):
            let routeType = type ?? preferredRouteType
            switch routeType {
            case let .push(animated):
                try push(fromVC: current, toVC: vc, animated: animated, url: url)
            case let .present(wrapper, modalPresentationStyle,animated):
                try present(fromVC: current, toVC: vc, wrapper: wrapper, modalPresentationStyle: modalPresentationStyle,animated: animated, url: url)
            }
        case .action(let action):
            action()
        }
    }
    
    private func push(fromVC: UIViewController?, toVC: UIViewController, animated: Bool = true, url: String) throws {
        guard let navigationController = fromVC?.navigationController else {
            throw PoRouterError.noPushBase(url: url)
        }
        navigationController.pushViewController(toVC, animated: animated)
    }
        
    private func present(fromVC: UIViewController?, toVC: UIViewController, wrapper: UINavigationController.Type?, modalPresentationStyle: UIModalPresentationStyle, animated: Bool = true, url: String) throws {
        guard let fromVC else {
            throw PoRouterError.noPresentBase(url: url)
        }
        var toVC = toVC
        if let wrapper {
            toVC = wrapper.init(rootViewController: toVC)
        }
        toVC.modalPresentationStyle = modalPresentationStyle
        fromVC.present(toVC, animated: animated, completion: nil)
    }
            
    private func buildRouterableResult(url: String, ctx: Context? = nil) throws -> PoRouterableResult {
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
        
        if interruptHandler?(url, urlComponents[0], params, ctx) == true {
            throw PoRouterError.interrupt(url: url)
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

private enum Constant {
    static let appleBundleSuffix = "com.apple"
    static let saveRegisterVersionKey = "saveRegisterVersionKey"
    static let saveRegisterCacheKey = "saveRegisterCacheKey"
}
