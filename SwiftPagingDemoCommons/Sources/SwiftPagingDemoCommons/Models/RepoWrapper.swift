//
//  Repo.swift
//  SwiftPagingDemo
//
//  Created by Gordan Glavaš on 31.05.2021..
//

import Foundation

public struct RepoWrapper: Codable {
    public let id: Int64
    public let name: String
    public let fullName: String
    public let description: String?
    public let url: String
    public let stars: Int
    public let forks: Int
    public let language: String?
    
    public enum CodingKeys: String, CodingKey {
        case id = "id",
             name = "name",
             fullName = "full_name",
             description = "description",
             url = "html_url",
             stars = "stargazers_count",
             forks = "forks_count",
             language = "language"
    }
}
