//
//  RepoSearchResponse.swift
//  SwiftPagingDemo
//
//  Created by Gordan Glavaš on 31.05.2021..
//

import Foundation

public struct RepoSearchResponse: Codable {
    public let total: Int?
    public let items: [RepoWrapper]
    public let nextPage: Int?
    
    public enum CodingKeys: String, CodingKey {
        case total = "total_count",
             items = "items",
             nextPage = "nextPage"
    }
}
