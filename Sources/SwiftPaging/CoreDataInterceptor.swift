//
//  File.swift
//  
//
//  Created by Gordan Glavaš on 01.06.2021..
//

import Foundation
import CoreData

/**

 It makes a distinction between your DB model (Value) and its remote variant (RemoteValue), allowing you to work with different models.
 If the model coming back from your remote API is exactly the same as your CoreDataModel, use the same value for Value and RemoteValue.
 */
public protocol CoreDataInterceptorDataSource {
    associatedtype Key: Equatable // request key
    associatedtype Value: NSManagedObject // CoreData model
    associatedtype RemoteValue // remote API model, can be the same as Value
    func get(request: PagingRequest<Key>) throws -> [Value] // fetch data from the DB based on the provided request
    func insert(remoteValues: [RemoteValue], in moc: NSManagedObjectContext) throws -> [Value] // store data that came from PagingSource into the DB and return the mapped values
    func deleteAll(in moc: NSManagedObjectContext) throws // clear the DB
}

/**
 Used for keys to pass parameters needed by **CoreDataInterceptor** in **PagingRequestParams.userInfo**.
 */
public enum CoreDataInterceptorUserInfoParams {
    case moc, // the NSManagedObjectContext to use with CoreData
         hardRefresh // set to true to purge the DB on a refresh
}

/**
 An Interceptor that fetches and stores data from a CoreData DB, allowing for persistent local storage of paged data. Uses **CoreDataInterceptorDataSource**
 implementation as an interface to the DB
 */
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
