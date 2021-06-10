//
//  File.swift
//  
//
//  Created by Gordan Glavaš on 31.05.2021..
//

import Foundation

public struct PagingKeyChain<Key: Equatable>: Equatable {
    public let key: Key
    public let prevKey: Key?
    public let nextKey: Key?
    
    public init(key: Key,
                prevKey: Key?,
                nextKey: Key?) {
        self.key = key
        self.prevKey = prevKey
        self.nextKey = nextKey
    }
}
