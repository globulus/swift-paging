//
//  File.swift
//  
//
//  Created by Gordan Glavaš on 31.05.2021..
//

import Foundation
import CoreData

public enum PagingInterceptResult<Key: Equatable, Value> {
    case proceed(PagingRequest<Key>, handleAfterwards: Bool),
         complete(Page<Key, Value>)
}

public class PagingInterceptor<Key: Equatable, Value> {
    public init() { }
    
    public func intercept(request: PagingRequest<Key>) throws -> PagingInterceptResult<Key, Value> {
        fatalError()
    }
    
    public func handle(result page: Page<Key, Value>) { }
}

// has to be here, because Swift
public let cacheInterceptorDefaultExpirationInterval = TimeInterval(10 * 60) // 10 min

public class CacheInterceptor<Key: Hashable, Value>: PagingInterceptor<Key, Value> {
    
    private let expirationInterval: TimeInterval
    private var cache = [Key: CacheEntry]()
    
    public init(expirationInterval: TimeInterval = cacheInterceptorDefaultExpirationInterval) {
        self.expirationInterval = expirationInterval
    }
    
    public override func intercept(request: PagingRequest<Key>) throws -> PagingInterceptResult<Key, Value> {
        pruneCache() // remove expired items
        if let cached = cache[request.key] {
            return .complete(cached.page) // complete the request with the cached page
        } else {
            return .proceed(request, handleAfterwards: true) // don't have data, proceed...
        }
    }
    
    public override func handle(result page: Page<Key, Value>) {
        cache[page.key] = CacheEntry(page: page) // store result in cache
    }
    
    private func pruneCache() {
        let now = Date().timeIntervalSince1970
        let keysToRemove = cache.keys.filter { now - (cache[$0]?.timestamp ?? 0) > expirationInterval }
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }
    
    private struct CacheEntry {
        let page: Page<Key, Value>
        let timestamp: TimeInterval = Date().timeIntervalSince1970
    }
}

public class LoggingInterceptor<Key: Equatable, Value>: PagingInterceptor<Key, Value> {
    private let log: (String) -> Void // allows for custom logging
    
    public init(log: ((String) -> Void)? = nil) {
        self.log = log ?? { print($0) }
    }
    
    public override func intercept(request: PagingRequest<Key>) throws -> PagingInterceptResult<Key, Value> {
        log("Sending pagination request: \(request)") // log the request
        return .proceed(request, handleAfterwards: true) // proceed with the request, without changing it
    }
    
    public override func handle(result page: Page<Key, Value>) {
        log("Received page: \(page)") // once the page is retuned, print it
    }
}
