//
//  RepoPagingSource.swift
//  SwiftPagingDemo
//
//  Created by Gordan Glavaš on 01.06.2021..
//

import Foundation
import Combine
import SwiftPaging

public enum PagingUserInfoParams: Hashable {
    case query
}

public extension PagingRequest {
    var query: String? {
        params.userInfo?[PagingUserInfoParams.query] as? String
    }
}

public class GithubPagingSource<DataSource: GithubDataSource>: PagingSource {
    private let service: GithubService
    private let dataSource: DataSource
    
    public init(service: GithubService,
         dataSource: DataSource) {
        self.service = service
        self.dataSource = dataSource
    }
    
    public func fetch(request: PagingRequest<Int>) -> PagingResultPublisher<Int, Repo> {
        guard let moc = request.moc,
              let query = request.query
        else {
            return Fail(outputType: Page<Int, Repo>.self, failure: URLError(.badURL))
                .eraseToAnyPublisher()
        }
        return service.getRepos(query: query, page: request.key, pageSize: request.params.pageSize)
            .tryMap { [self] wrappers in
                print("paging source returned \(wrappers.count) items for request: \(request)")
                let repos = try dataSource.insert(remoteValues: wrappers, in: moc)
                return Page(request: request, values: repos)
            }.eraseToAnyPublisher()
    }
    
    public let refreshKey: Int = 0
    
    public func keyChain(for key: Int) -> PagingKeyChain<Int> {
        PagingKeyChain(key: key,
                       prevKey: (key == 0) ? nil : (key - 1),
                       nextKey: key + 1)
    }
}

public struct GithubPagingState: PaginationManagerOutput {
    public static let initial = GithubPagingState(isRefreshing: false,
                                           isPrepending: false,
                                           isAppending: false,
                                           values: [])
    
    public let isRefreshing: Bool
    public let isPrepending: Bool
    public let isAppending: Bool
    public let values: [Repo]
    
    public init(isRefreshing: Bool,
                isPrepending: Bool,
                isAppending: Bool,
                values: [Repo]) {
        self.isRefreshing = isRefreshing
        self.isPrepending = isPrepending
        self.isAppending = isAppending
        self.values = values
    }
}

public class GithubPaginationManager<PagingSource: GithubPagingSource<GithubDataSourceImpl>>: PaginationManager<Int, Repo, PagingSource, GithubPagingState> {
    
}
