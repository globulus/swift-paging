//
//  Repo+CoreDataProperties.swift
//  SwiftPagingDemo
//
//  Created by Gordan Glavaš on 31.05.2021..
//
//

import Foundation
import CoreData


public extension Repo {
    static let entityName = "Repo"
    
    @nonobjc class func fetchRequest() -> NSFetchRequest<Repo> {
        return NSFetchRequest<Repo>(entityName: entityName)
    }

    @NSManaged var id: Int64
    @NSManaged var name: String?
    @NSManaged var fullName: String?
    @NSManaged var desc: String?
    @NSManaged var url: String?
    @NSManaged var stars: Int32
    @NSManaged var forks: Int32
    @NSManaged var language: String?

}

extension Repo : Identifiable {

}
