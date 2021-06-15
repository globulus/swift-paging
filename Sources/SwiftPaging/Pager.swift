//
//  File.swift
//  
//
//  Created by Gordan Glavaš on 31.05.2021..
//

import Foundation
import Combine

public enum PagingState<Key: Equatable, Value> {
    case refreshing,
         prepending,
         appending,
         done(Page<Key, Value>)
}

private let deduplicationInterval: TimeInterval = 0.25

/**
 Pager is the glue that binds all PagingSource, RequestPublisher components together, mapping requests from the publisher, passing through interceptor and finally to the paging source.
 It publishes PagingStates that allow your app to respond to paging events and update the UI. Working with a Pager directly offers the most flexibility and customizations.
 */
public class Pager<Key, Value, Source: PagingSource> where Source.Key == Key, Source.Value == Value {
    public typealias Interceptor = PagingInterceptor<Key, Value>
    public typealias Result = PagingState<Key, Value>
    
    public let source: Source
    public let interceptors: [Interceptor]
    
    private var subs = Set<AnyCancellable>()
    
    private let subject = PassthroughSubject<Result, Error>()
    public var publisher: AnyPublisher<Result, Error> {
        subject.eraseToAnyPublisher()
    }
    
    public init(pagingSource: Source,
                requestSource: PagingRequestSource<Key>,
                interceptors: [Interceptor] = []) {
        self.source = pagingSource
        self.interceptors = interceptors
        requestSource.publisher
            .removeDuplicates(by: { previous, current in
                current.matches(previous) && current.params.timestamp - previous.params.timestamp < deduplicationInterval
            }).handleEvents(receiveOutput: { [self] request in
                let state: PagingState<Key, Value>
                switch request {
                case .refresh(_):
                    state = .refreshing
                case .prepend(_):
                    state = .prepending
                case .append(_):
                    state = .appending
                }
                subject.send(state)
            }).tryMap { request -> InterceptedRequest in
                var mutableRequest = request
                var interceptorsToHandleAfterwards = [Interceptor]()
                for interceptor in interceptors {
                    let result = try interceptor.intercept(request: mutableRequest)
                    switch result {
                    case .proceed(let newRequest, handleAfterwards: let handleAfterwards):
                        mutableRequest = newRequest
                        if handleAfterwards {
                            interceptorsToHandleAfterwards.append(interceptor)
                        }
                    case .complete(_):
                        return InterceptedRequest(result: result,
                                                  interceptorsToHandleAfterwards: interceptorsToHandleAfterwards)
                    }
                }
                return InterceptedRequest(result: .proceed(mutableRequest, handleAfterwards: false),
                                          interceptorsToHandleAfterwards: interceptorsToHandleAfterwards)
            }.flatMap { [self] intercepted -> PagingResultPublisher<Key, Value> in
                switch intercepted.result {
                case .proceed(let request, handleAfterwards: _):
                    return source.fetch(request: request)
                        .retry(times: request.params.retryPolicy?.maxRetries ?? 0,
                               if: request.params.retryPolicy?.shouldRetry ?? { _ in false })
                        .handleEvents(receiveOutput: { result in
                            for interceptor in intercepted.interceptorsToHandleAfterwards {
                                interceptor.handle(result: result)
                            }
                        }).eraseToAnyPublisher()
                case .complete(let result):
                    return Just(result)
                        .setFailureType(to: Error.self)
                        .eraseToAnyPublisher()
                }
            }.sink { [self] completion in
                if case .failure(_) = completion {
                    subject.send(completion: completion)
                }
            } receiveValue: { [self] page in
                subject.send(.done(page))
            }.store(in: &subs)
    }
    
    private struct InterceptedRequest {
        let result: PagingInterceptResult<Key, Value>
        let interceptorsToHandleAfterwards: [Interceptor]
    }
}
