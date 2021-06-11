# SwiftPaging

Swift Paging is a framework that helps you load and display pages of data from a larger dataset from local storage or over network. This approach allows your app to use both network bandwidth and system resources more efficiently. It is fully build on top of **Combine**, allowing you to harness its power, handle errors, etc.

## Features

 * A *server-client* architecture for requesting and receiving data.
 * Requests and responses go through Combine.
 * Support for **interceptors** that allow for custom logic - logging, caching, CoreData interop, etc.
 * Built-in deduplication of requests, conditional retries and error handling.
 * Automatic state management - know what paging operation your apps is currently doing and which data is available to it.
 
 ## Installation
 
 This framework is distributed as a **Swift Package**. Simply add the URL of this Git to your dependencies list and it'll work.
 
SwiftPaging is written in pure Swift and contains no platform dependencies. It relies on **Combine**, which means that it can be used on:
 * iOS 13 and above
 * MacOS 10.15 and above
 * tvOS 13 and above
 * WatchOS 6 and above
 
 ## Demo apps
 
 If you want to jump straight to the action, there are two demo apps you can try - implemented in [UIKit](SwiftPagingDemo) or [SwiftUI](SwiftPagingDemoSwiftUI). They both do the same thing - represent an **infinite scroll** of Github repositories that contain the word *swift*. The lists are **refreshable** and the apps use **CoreData for local storage**. The gist of the code lives [in the shared Swift Package](SwiftPagingDemoCommons). Overall, it represents a good use case for the framework.

## Core Concepts

SwiftPaging tries to make complex things simple, but it still may seem like there're a lot of concepts to swallow. However, all you need to do to get going is to [implement a `PagingSource`](#implementing-a-pagingsource). If you want to use `CoreDataPagingInterceptor`,  you'll need to [implement a `CoreDataInterceptorDataSource`](#storing-pages-in-db) as well. Beyond that, `PaginationManager` will provide you with the [state publisher and interface methods](#using-paginationmanager).

### TL;DR

1. `PagingSource` is your remote API. `CoreDataInterceptorDataSource` is your DAO. Both know how to get values (a `Page`) based on parameters from `PagingRequest` - its key, page size, etc.
1. When you want data, tell your `PaginationManager` to refresh, prepend or append data, depending on what you want . It'll send a request that uniquely identifies the data that should come back via its `key` and `params`.
1. Your `PaginationManager` will also notify its publisher that a paging event is happening, so that it can update its UI.
1. `PagingRequest` goes through `PagingInterceptor`s. One of them, `CoreDataPagingInterceptor` check if it has the requested data in the local DB. If yes, it returns it immediately.
1. If the data isn't locally present, the request goes to your `PagingSource` (representing your remote API), which does all the networking and gets the data from the back end.
1. `PaginationManager` updates the state with new data and publishes it to any subscribers.

### In depth

 * Your data is organized in **Pages**. Each `Page` references the **request** that produced it and contains an array of **values**.
 * A **PagingRequest** is an event that prompts the framework to return a `Page`. The request contains the **KeyChain**, as well as other parameters (which are customizable). There are 3 types of requests - **refresh**, **prepend** and **append**. You can tweak their exact meaning in your code, but the default `PaginationManager` takes refresh as the one that updates all the data, append the one that adds data to the end, and prepend as the one that adds data to the start.
 * Each `Page` is uniquely identified by its `key`. The `PagingRequest`  contains a `KeyChain`, which is the current key, plus its predecessor and successor (if there are any). This allows paging requests to be chained and for the system to keep track on which page to load next.
* A **RequestPublisher** is a Combine publisher that produces requests on-demand. Each `PaginationManager` has a built-in publisher, allowing you to easily send requests using methods (`request`, `prepend` or `append`).
 * **PagingSource** responds to **PagingRequests** and provides **Pages**. Normally, it represents your remote data source, such as the API your app is consuming to fetch data. Besides this, a `PagingSource` know the initial key (via `refreshKey`), and provides the key chain for the given key.
 * You can place **PagingInterceptors** between your `RequestPublisher` and `PagingSource`. Interceptors can inspect the request, modify it, or even return data. Examples are:
   * `LoggingInterceptor` - simply inspects requests and logs what goes on.
   * `CacheInterceptor` - caches data locally and returns if available.
   * `CoreDataInterceptor` - stores data in a local DB and returns if available.
* **Pager** is the glue that binds all these components together, mapping requests from the publisher, passing through interceptor and finally to the paging source. It publishes **PagingStates** that allow your app to respond to paging events and update the UI. Working with a `Pager` directly offers the most flexibility and customizations.
* **PaginationManager** is a util class that wraps together a `RequestPublisher` and a `Pager` and exposes a simpler interface that should suffice for most apps.
  * You can trigger requests using methods - `refresh`, `prepend` and `append`.
  * Keeps track of request order, and makes sure that refresh updates all the data, while prepend and append add the data to beginning and end, respectively.
  * It publishes a `PaginationManagerOutput`which contains the full pagination state. You can implement your own `PaginationManagerOutput` or use the `DefaultPaginationManagerOutput` implementation.

## Implementing a PagingSource

A `PagingSource` responds to `PagingRequests` and returns `Pages`. It also knows where does paging start and what are its boundaries (first and last page). `PagingSource` normally represents your remote API, but can represent any paginated data source.

In the demo apps, the `PagingSource` fetches `Repo`s from Github's API. It pages are identifies by numbers, so its `Key` is `Int`. It has three overrides:

* `refreshKey` tells the origin point of pagination, the key of the first page:

```swift
public let refreshKey: Int = 0
```

* `keyChain(for:)` tells how are keys linked together, i.e for a given key, what is its previous key, and what is the next one:

```swift
public func keyChain(for key: Int) -> PagingKeyChain<Int> {
    PagingKeyChain(key: key,
                   prevKey: (key == 0) ? nil : (key - 1),
                   nextKey: key + 1)
}
```

* `fetch(request:)` produces a `Publisher<Repo, Error>` for the given request. Note how requests can hold custom data in their `params.userInfo`:

```swift
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
```

## Storing pages in DB

A common use case is to have a permanent client-side storage in the form of CoreData. SwiftPaging makes placing the DB between your app and its remote source dead easy via `CoreDataInterceptor`. (This is an interceptor - [read more on interceptors here](#interceptors)).

To use `CoreDataInterceptor`, you must do two things:

1. Pass a `NSManagedObjectContext`  in `PagingRequestParams.userInfo`. You should use `CoreDataInterceptorUserInfoParams.moc` as the key ([check out sample for how it's done](SwiftPagingDemoCommons/Sources/SwiftPagingDemoCommons)). Also, if you want the `refresh` request to clear your DB, add `CoreDataInterceptorUserInfoParams.hardRefresh: true` to the userInfo dictionary as well.
2. Define a `CoreDataInterceptorDataSource` implementation, so that `CoreDataInterceptor`  know how to interface with your data - namely, how to:
  * read data from the DB for the given request via `get(request:)`,
  * write a batch of remote data via `insert(remoteValues:in:)`,
  * clear the DB via  `deleteAll(in:)`.

Here's the implementation from the demo apps:

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

> The specific nature of CoreData will most likely force you to use your data source in your paging source, since Values are created via Value(entity:insertInto:).

## Using PaginationManager

`PaginationManager` is a util class that makes it dead easy to tie your `PagingSource` and `Interceptors` and provide your app with a state publisher. `PaginationMangager` works out of the box, but you'll usually want to set it up with parameters specific to your app:

```swift
public class GithubPaginationManager<PagingSource: GithubPagingSource<GithubDataSourceImpl>>: PaginationManager<Int, Repo, PagingSource, GithubPagingState> { }
```

Then, instantiate it with your source and interceptors:

```swift
dataSource = GithubDataSourceImpl(persistentStoreCoordinator: PersistenceController.shared.container.persistentStoreCoordinator)
paginationManager = GithubPaginationManager(source: GithubPagingSource(service: GithubServiceImpl(), dataSource: dataSource),
                                            pageSize: 15,
                                            interceptors: [LoggingInterceptor<Int, Repo>(), CoreDataInterceptor(dataSource: dataSource)])
```

Then, subscribe to its state publisher wherever necessary. Here's the example from the SwiftUI demo:

```swift
paginationManager.publisher
    .subscribe(on: DispatchQueue.init(label: "myQ", qos: .background, attributes: [], autoreleaseFrequency: .never, target: nil))
    .replaceError(with: GithubPagingState.initial)
    .receive(on: DispatchQueue.main)
    .sink { [self] state in
        if !state.isRefreshing {
            refreshComplete?()
            refreshComplete = nil
        }
        repos = state.values
        isAppending = state.isAppending
    }.store(in: &subs)
```

When you need paginaton to happen, just trigger its methods - `refresh`,  `prepend` or `append`. It's as simple as that!

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

[CoreDataInterceptor](Sources/SwiftPaging/CoreDataInterceptor.swift) works in a similar fashion.

### Writing your own interceptor

Creating an interceptor is easy enough:

1. Subclass `PagingInterceptor`.
1. Override `intercept(request:)`. From it, return:
  1. `.complete(Page)` if your interceptor should respond to the request and terminate furhter request propagation.
  1. `.proceed(PagingRequest, handleAfterwards: Bool)` if the request should go forward. You can modify the original request in any way you want, or keep it as is. Set `handleAfterwards:` parameter to `true` if you want `handle(result:)` to be invoked for this interceptor once the response `Page` comes back.
1. Override `handle(result:)` to observe the `Page` generated for the request.
