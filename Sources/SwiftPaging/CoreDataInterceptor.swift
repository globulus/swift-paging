//
//  File.swift
//  
//
//  Created by Gordan Glavaš on 01.06.2021..
//

import Foundation
import CoreData

public protocol CoreDataInterceptorDataSource {
    associatedtype Key: Equatable
    associatedtype Value: NSManagedObject
    associatedtype RemoteValue
    func get(request: PagingRequest<Key>) throws -> [Value]
    func insert(remoteValues: [RemoteValue], in moc: NSManagedObjectContext) throws -> [Value]
    func deleteAll(in moc: NSManagedObjectContext) throws
}

public enum CoreDataInterceptorUserInfoParams {
    case moc, hardRefresh
}

public class CoreDataInterceptor<Key, Value, DataSource: CoreDataInterceptorDataSource>: PagingInterceptor<Key, Value>
where DataSource.Key == Key, DataSource.Value == Value {
    private let dataSource: DataSource
    
    public required init(dataSource: DataSource) {
        self.dataSource = dataSource
    }
    
    public override func intercept(request: PagingRequest<Key>) throws -> PagingInterceptResult<Key, Value> {
        guard let moc = request.moc
        else {
            return .proceed(request, handleAfterwards: false)
        }
        if case .refresh(_) = request,
           (request.params.userInfo?[CoreDataInterceptorUserInfoParams.hardRefresh] as? Bool) == true {
            try dataSource.deleteAll(in: moc)
        }
        let pageSize = request.params.pageSize
        let values = try dataSource.get(request: request)
        if values.count < pageSize {
            print("db proceed, don't have data")
            return .proceed(request, handleAfterwards: false) // done automatically
        } else {
            print("db has data for request: \(request)")
            return .complete(Page(request: request, values: values))
        }
    }
}

public extension PagingRequest {
    var moc: NSManagedObjectContext? {
        params.userInfo?[CoreDataInterceptorUserInfoParams.moc] as? NSManagedObjectContext
    }
}
