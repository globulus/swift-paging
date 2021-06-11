//
//  ContentViewModel.swift
//  SwiftPagingDemoSwiftUI
//
//  Created by Gordan Glavaš on 10.06.2021..
//

import Foundation
import SwiftUI
import SwiftUIPullToRefresh
import SwiftPagingDemoCommons
import Combine
import SwiftPaging

class ContentViewModel: ObservableObject {
    @Published var repos = [Repo]()
    @Published var isAppending = false
    
    private var dataSource: GithubDataSourceImpl!
    private var paginationManager: GithubPaginationManager<GithubPagingSource<GithubDataSourceImpl>>!
    private var subs = Set<AnyCancellable>()
    private var refreshComplete: RefreshComplete?
    
    private var paginationUserInfo: PagingRequestParamsUserInfo {
        [CoreDataInterceptorUserInfoParams.moc: PersistenceController.shared.container.viewContext,
         PagingUserInfoParams.query: "swift"]
    }
    
    init() {
        dataSource = GithubDataSourceImpl(persistentStoreCoordinator: PersistenceController.shared.container.persistentStoreCoordinator)
        paginationManager = GithubPaginationManager(source: GithubPagingSource(service: GithubServiceImpl(), dataSource: dataSource),
                                                    pageSize: 15,
                                                    interceptors: [LoggingInterceptor<Int, Repo>(), CoreDataInterceptor(dataSource: dataSource)])
        
        paginationManager.publisher
            .replaceError(with: GithubPagingState.initial)
            .sink { [self] state in
            if !state.isRefreshing {
                refreshComplete?()
                refreshComplete = nil
            }
            repos = state.values
            isAppending = state.isAppending
        }.store(in: &subs)
    }
    
    func loadMore() {
        paginationManager.append(userInfo: paginationUserInfo)
    }
    
    func refresh(refreshComplete: RefreshComplete? = nil) {
        self.refreshComplete = refreshComplete
        paginationManager.refresh(userInfo: paginationUserInfo)
    }
}
