//
//  GithubDataSource.swift
//  SwiftPagingDemo
//
//  Created by Gordan Glavaš on 01.06.2021..
//

import Foundation
import CoreData
import Combine
import SwiftPaging

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
