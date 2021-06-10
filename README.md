# SwiftPaging

Swift Paging is a framework that helps you load and display pages of data from a larger dataset from local storage or over network. This approach allows your app to use both network bandwidth and system resources more efficiently. It is fully build on top of **Combine**, allowing you to harness its power, handle errors, etc.

## Features

 * A *server-client* architecture for requesting and receiving data.
 * Requests and responses go through Combine.
 * Support for **interceptors** that allow for custom logic - logging, caching, CoreData interop, etc.
 * Built-in deduplication of requests, conditional retries and error handling.
 * Automatic state management - know what paging operation your apps is currently doing and which data is available to it.
 
 ## Installation
 
 This component is distributed as a **Swift Package**. Simply add the URL of this Git to your dependencies list and it'll work.
 
 ## Demo apps
 
 If you want to jump straight to the action, there are two demo apps you can try - implemented in [UIKit]() or [SwiftUI](). They both do the same thing - represent an infinite scroll of Github repositories that contain the word *swift*. The lists are refreshable and the apps use CoreData for local storage. Overall, it represents a good use case for the framework.

## Core Concepts

### TL;DR

1. When you want data, have your `RequestPublisher` send a `PagingRequest`. The request uniquely identifies the data that should come back via its `key` and `params`. It represents a refresh, prepending or appending operation.
1. Your `PaginationManager` will notify your app that the request is processed, so that it updates its UI.
1. `PagingRequest` goes through `PagingInterceptor`s. One of them, `CoreDataPagingInterceptor` check if it has the requested data in the local DB. If it has, it returns it immediately.
1. If the data isn't locally present, the request goes to your `PagingSource` (representing your remote API), which does all the networking and gets the data from the back end.
1. `PaginationManager` updates the state with new data and publishes it to any subscribers.

There might seem like many concepts, but in reality you only need to implement `PagingSource` and `PaginationManagerOutput`. If you want to use `CoreDataPagingInterceptor`,  you'll need to implement a `CoreDataInterceptorDataSource` as well.

### In depth

 * Your data is organized in **Pages**. Each `Page` has an ID that identifies it in your paging structure, and contains an array of **values**.
 * A **PagingRequest** is an event that prompts the framework to return a **Page**. The request contains the Key, as well as other parameters (which are customizable). There are 3 types of requests: refresh, append and prepend. A **RequestPublisher** is a Combine publisher that produces requests on-demand.
 * **PagingSource** respons to **PagingRequests** and provides **Pages**. Normally, it represents your remote data source, such as the API your app is consuming to fetch data. Your sturcture should only have a single paging source.
 * You can place **PagingInterceptors** between your **RequestPublisher** and **PagingSource**. Interceptors can inspect the request, modify it, or even return data. Examples are:
   * Logging interceptor - simply inspects requests and logs what goes on.
   * CachingInterceptor - caches data locally and returns if available. Same with CoreDataInterceptor.
* **Pager** is the glue that binds all these components together, mapping requests from the publisher, passing through interceptor and finally to the paging source.
* **PaginationManager** ties in the State component to all, allowing you to monitor all the values, state of refreshing etc.

## Implementing a PagingSource

## Storing pages in DB

A common use case is to have a permanent client-side storage in the form of CoreData DB. SwiftPaging allows you fetch pages from the DB and store them. (This is an interceptor - [read more on interceptors here](#interceptors)).

To use `CoreDataInterceptor`, you must do two things:

1. Pass a `NSManagedObjectContext`  in `PagingRequestParams.userInfo`. You should use `CoreDataInterceptorUserInfoParams.moc` as the key. [Check out sample for how it's done](). Also, if you want the `refresh` request to clear your DB, add `CoreDataInterceptorUserInfoParams.hardRefresh: true` to the userInfo dictionary as well.
2. Define a `CoreDataInterceptorDataSource` implementation, so that `CoreDataInterceptor`  know how to interface with your data - namely, how to read, store and delete them. Here's the implementation from the GitHub Page.

> Note that `CoreDataInterceptorDataSource` makes a distinction between your DB model (`Value`) and its remote variant (`RemoteValue`), allowing you to work with different models. If the model coming back from your remote API is exactly the same as your CoreDataModel, use the same value for `Value` and `RemoteValue`.

```swift
public protocol GithubDataSource: CoreDataInterceptorDataSource where Key == Int, Value == Repo, RemoteValue == RepoWrapper {

}

public class GithubDataSourceImpl: GithubDataSource {
    private let persistentStoreCoordinator: NSPersistentStoreCoordinator
    
    public init(persistentStoreCoordinator: NSPersistentStoreCoordinator) {
        self.persistentStoreCoordinator = persistentStoreCoordinator
    }
    
    public func get(request: PagingRequest<Int>) throws -> [Repo] {
        let moc = request.moc!
        let query = request.query!
        let fetchRequest = Repo.fetchRequest() as NSFetchRequest<Repo>
        fetchRequest.predicate = NSPredicate(format: "(%K CONTAINS[cd] %@) OR (%K CONTAINS[cd] %@)", #keyPath(Repo.name), query, #keyPath(Repo.desc), query)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Repo.stars, ascending: false),
                                        NSSortDescriptor(keyPath: \Repo.name, ascending: true)
        ]
        let pageSize = request.params.pageSize
        fetchRequest.fetchOffset = request.key * pageSize
        fetchRequest.fetchLimit = pageSize
        return try moc.fetch(fetchRequest)
    }
    
    public func insert(remoteValues: [RepoWrapper], in moc: NSManagedObjectContext) throws -> [Repo] {
        let entity = NSEntityDescription.entity(forEntityName: Repo.entityName, in: moc)!
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Repo.entityName)
        var repos = [Repo]()
        for wrapper in remoteValues {
            fetchRequest.predicate = NSPredicate(format: "id == %d", wrapper.id)
            try persistentStoreCoordinator.execute(NSBatchDeleteRequest(fetchRequest: fetchRequest), with: moc)
            let repo = Repo(entity: entity, insertInto: moc)
            repo.fromWrapper(wrapper)
            repos.append(repo)
        }
        try moc.save()
        return repos
    }
    
    public func deleteAll(in moc: NSManagedObjectContext) throws {
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: Repo.entityName)
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        try persistentStoreCoordinator.execute(deleteRequest, with: moc)
    }
}
```
Then, just add `CoreDataInterceptor`  to your interceptors array:

```swift
interceptors: [..., CoreDataInterceptor(dataSource: dataSource), ...])
```

> The specific nature of CoreData will most likely force you to use your data source in your paging source...

## Using PaginationManager

## Interceptors

Interceptors are a powerful mechanism that can monitor and rewrite requests, or even complete them on the spot. After a `Page` is returned, all interceptors are notified of it, and can use it to modify their internal state. You can chain any number of interceptors in your **Pager**.

The built-in `LoggingInterceptor`  is an example of a passive interceptor that analyzes request and response and prints it to a log:

```swift
public class LoggingInterceptor<Key: Equatable, Value>: PagingInterceptor<Key, Value> {
    private let log: (String) -> Void // allows for custom logging

    public init(log: ((String) -> Void)? = nil) {
        self.log = log ?? { print($0) }
    }

    public override func intercept(request: PagingRequest<Key>) throws -> PagingInterceptResult<Key, Value> {
        log("Sending pagination request: \(request)") // log the request
        return .proceed(request, handleAfterwards: true) // proceed with the request, without changing it
    }

    public override func handle(result page: Page<Key, Value>) {
        log("Received page: \(page)") // once the page is retuned, print it
    }
}
```

On the other hand, `CacheInterceptor` checks if it has the page available locally, and terminates the request chain if so:

```swift
public let cacheInterceptorDefaultExpirationInterval = TimeInterval(10 * 60) // 10 min

public class CacheInterceptor<Key: Hashable, Value>: PagingInterceptor<Key, Value> {
    private let expirationInterval: TimeInterval
    private var cache = [Key: CacheEntry]()
    
    public init(expirationInterval: TimeInterval = cacheInterceptorDefaultExpirationInterval) {
        self.expirationInterval = expirationInterval
    }
    
    public override func intercept(request: PagingRequest<Key>) throws -> PagingInterceptResult<Key, Value> {
        pruneCache() // remove expired items
        if let cached = cache[request.key] {
            return .complete(cached.page) // complete the request with the cached page
        } else {
            return .proceed(request, handleAfterwards: true) // don't have data, proceed...
        }
    }
    
    public override func handle(result page: Page<Key, Value>) {
        cache[page.key] = CacheEntry(page: page) // store result in cache
    }
    
    private func pruneCache() {
        let now = Date().timeIntervalSince1970
        let keysToRemove = cache.keys.filter { now - (cache[$0]?.timestamp ?? 0) > expirationInterval }
        for key in keysToRemove {
            cache.removeValue(forKey: key)
        }
    }
    
    private struct CacheEntry {
        let page: Page<Key, Value>
        let timestamp: TimeInterval = Date().timeIntervalSince1970
    }
}
```

[CoreDataInterceptor]() works in a similar fashion.

### Writing your own interceptor

Creating an interceptor is easy enough:

1. Subclass `PagingInterceptor`.
1. Override `intercept(request:)`. From it, return:
  1. `.complete(Page)` if your interceptor should respond to the request and terminate furhter request propagation.
  1. `.proceed(PagingRequest, handleAfterwards: Bool)` if the request should go forward. You can modify the original request in any way you want, or keep it as is. Set `handleAfterwards:` parameter to `true` if you want `handle(result:)` to be invoked for this interceptor once the response `Page` comes back.
1. Override `handle(result:)` to observe the `Page` generated for the request.
