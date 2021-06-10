//
//  File.swift
//  
//
//  Created by Gordan Glavaš on 31.05.2021..
//

import Foundation

/**
 Represents a response to a single **PagingRequest** and contains an array of Values.
 */
public class Page<Key: Equatable, Value> {
    public let request: PagingRequest<Key>
    public let values: [Value]
    
    public init(request: PagingRequest<Key>,
                values: [Value]) {
        self.request = request
        self.values = values
    }
}

public extension Page {
    /**
     A key identifies a page and its request.
     */
    var key: Key {
        request.key
    }
    
    /**
     A page is complete if it has as many values as requested (by the pageSize param of the request).
     */
    var isComplete: Bool {
        values.count == request.params.pageSize
    }
}
