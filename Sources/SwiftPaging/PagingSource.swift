//
//  File.swift
//  
//
//  Created by Gordan Glavaš on 31.05.2021..
//

import Foundation
import Combine

public typealias PagingResultPublisher<Key: Equatable, Value> = AnyPublisher<Page<Key, Value>, Error>

/**
 Represents a "server" that responds to **PagingRequests** via a **Publisher**.
 */
public protocol PagingSource: AnyObject {
    associatedtype Key: Equatable
    associatedtype Value
    
    var refreshKey: Key { get }
    func keyChain(for key: Key) -> PagingKeyChain<Key>
    func fetch(request: PagingRequest<Key>) -> PagingResultPublisher<Key, Value>
}
