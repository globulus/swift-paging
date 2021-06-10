//
//  File.swift
//  
//
//  Created by Gordan Glavaš on 31.05.2021..
//

import Foundation
import Combine

public enum PagingRequest<Key: Equatable> {
    case refresh(PagingRequestParams<Key>),
         prepend(PagingRequestParams<Key>),
         append(PagingRequestParams<Key>)
}

public extension PagingRequest {
    var params: PagingRequestParams<Key> {
        switch self {
        case .refresh(let params):
            return params
        case .prepend(let params):
            return params
        case .append(let params):
            return params
        }
    }
    
    var key: Key {
        params.keyChain.key
    }
}

extension PagingRequest {
    func matches(_ other: PagingRequest) -> Bool {
        switch (self, other) {
        case (let .refresh(lhsParams), let .refresh(rhsParams)):
            return lhsParams.matches(rhsParams)
        case (let .prepend(lhsParams), let .prepend(rhsParams)):
            return lhsParams.matches(rhsParams)
        case (let .append(lhsParams), let .append(rhsParams)):
            return lhsParams.matches(rhsParams)
        default:
            return false
        }
    }
}

public typealias PagingRequestParamsUserInfo = [AnyHashable: Any?]?

public struct PagingRequestParams<Key: Equatable> {
    public let keyChain: PagingKeyChain<Key>
    public let pageSize: Int
    public let retryPolicy: RetryPolicy?
    public let userInfo: PagingRequestParamsUserInfo
    
    let timestamp: TimeInterval
    
    public init(keyChain: PagingKeyChain<Key>,
                pageSize: Int,
                retryPolicy: RetryPolicy? = nil,
                userInfo: PagingRequestParamsUserInfo = nil) {
        self.keyChain = keyChain
        self.pageSize = pageSize
        self.retryPolicy = retryPolicy
        self.userInfo = userInfo
        
        timestamp = NSDate().timeIntervalSince1970
    }
}

extension PagingRequestParams {
    func matches(_ other: PagingRequestParams) -> Bool {
        keyChain == other.keyChain && pageSize == other.pageSize
    }
}

public struct RetryPolicy {
    public let maxRetries: Int
    public let shouldRetry: (Error) -> Bool
    
    public init(maxRetries: Int,
                shouldRetry: @escaping (Error) -> Bool) {
        self.maxRetries = maxRetries
        self.shouldRetry = shouldRetry
    }
}

public class PagingRequestSource<Key: Equatable> {
    public typealias Request = PagingRequest<Key>
    
    private let subject = PassthroughSubject<Request, Never>()
    
    public var publisher: AnyPublisher<Request, Never> {
        subject.eraseToAnyPublisher()
    }
    
    public func send(request: Request) {
        subject.send(request)
    }
}
