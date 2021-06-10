//
//  GithubService.swift
//  SwiftPagingDemo
//
//  Created by Gordan Glavaš on 01.06.2021..
//

import Foundation
import Combine
import CoreData

public protocol GithubService: AnyObject {
    func getRepos(query: String, page: Int, pageSize: Int) -> AnyPublisher<[RepoWrapper], Error>
}

public class GithubServiceImpl: GithubService {
    public init() { }
    
    public func getRepos(query: String, page: Int, pageSize: Int) -> AnyPublisher<[RepoWrapper], Error> {
        let apiQuery = query + "in:name,description"
        return URLSession.shared
            .dataTaskPublisher(for: URL(string: "https://api.github.com/search/repositories?sort=stars&q=\(apiQuery)&page=\(page)&per_page=\(pageSize)")!)
            .map(\.data)
            .decode(type: RepoSearchResponse.self, decoder: JSONDecoder())
            .map(\.items)
            .eraseToAnyPublisher()
    }
}
