//
//  ViewController.swift
//  SwiftPagingDemo
//
//  Created by Gordan Glavaš on 31.05.2021..
//

import UIKit
import Combine
import SwiftPaging
import SwiftPagingDemoCommons
import CombineDataSources

class ViewController: UIViewController {
    private let pageSize = 15
    @IBOutlet weak var tableView: UITableView!
    
    private var dataSource: GithubDataSourceImpl!
    private var paginationManager: GithubPaginationManager<GithubPagingSource<GithubDataSourceImpl>>!
    private var subs = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        let refreshControl = UIRefreshControl()
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = refreshControl
        dataSource = GithubDataSourceImpl(persistentStoreCoordinator: appDelegate!.persistentContainer.persistentStoreCoordinator)
        paginationManager = GithubPaginationManager(source: GithubPagingSource(service: GithubServiceImpl(), dataSource: dataSource),
                                                    pageSize: 15,
                                                    interceptors: [LoggingInterceptor<Int, Repo>(), CoreDataInterceptor(dataSource: dataSource)])
        
        let pub = paginationManager.publisher
            .subscribe(on: DispatchQueue.init(label: "myQ", qos: .background, attributes: [], autoreleaseFrequency: .never, target: nil))
            .replaceError(with: GithubPagingState.initial)
            .receive(on: DispatchQueue.main)
            
        pub.sink { [self] state in
            tableView.refreshControl?.endRefreshing()
            tableView.tableFooterView = (state.isAppending || state.isRefreshing) ? footerActivityIndicator : nil
        }.store(in: &subs)
        pub.map(\.values)
            .bind(subscriber: tableView.rowsSubscriber(cellIdentifier: "Cell", cellType: UITableViewCell.self, cellConfig: { cell, indexPath, repo in
            cell.textLabel?.text = "\(repo.name ?? "") \(repo.stars) \(repo.forks)"
            cell.detailTextLabel?.text = repo.url
        })).store(in: &subs)
        
        paginationManager.refresh(userInfo: paginationUserInfo)
    }
    
    @objc func refresh() {
        var userInfo = paginationUserInfo
        userInfo?[CoreDataInterceptorUserInfoParams.hardRefresh] = true
        paginationManager.refresh(userInfo: userInfo)
    }
    
    var paginationUserInfo: PagingRequestParamsUserInfo {
        [CoreDataInterceptorUserInfoParams.moc: appDelegate?.persistentContainer.viewContext, PagingUserInfoParams.query: "swift"]
    }
    
    var footerActivityIndicator: UIView {
        let view = UIActivityIndicatorView(style: .large)
        view.startAnimating()
        view.frame = CGRect(x: CGFloat(0), y: CGFloat(0), width: tableView.bounds.width, height: CGFloat(44))
        return view
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1 {
            paginationManager.append(userInfo: paginationUserInfo)
        }
    }
}

