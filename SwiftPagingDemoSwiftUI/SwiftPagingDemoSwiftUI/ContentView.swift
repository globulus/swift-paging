//
//  ContentView.swift
//  SwiftPagingDemoSwiftUI
//
//  Created by Gordan Glavaš on 07.06.2021..
//

import SwiftUI
import CoreData
import SwiftUIInfiniteList
import SwiftUIPullToRefresh

struct ContentView: View {
    @ObservedObject var viewModel: ContentViewModel

    var body: some View {
        InfiniteList(data: $viewModel.repos,
                     isLoading: $viewModel.isAppending,
                     loadingView: ProgressView(),
                     loadMore: viewModel.loadMore,
                     onRefresh: viewModel.refresh(refreshComplete:)) { repo in
            VStack(alignment: .leading) {
                Text("\(repo.name ?? "") \(repo.stars) \(repo.forks)")
                    .font(.system(size: 14))
                Text(repo.url ?? "")
            }.padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: ContentViewModel())
    }
}
