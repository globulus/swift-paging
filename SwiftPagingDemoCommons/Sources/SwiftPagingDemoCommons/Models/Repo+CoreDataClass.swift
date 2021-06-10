//
//  Repo+CoreDataClass.swift
//  SwiftPagingDemo
//
//  Created by Gordan Glavaš on 31.05.2021..
//
//

import Foundation
import CoreData

@objc(Repo)
public class Repo: NSManagedObject {
    public func fromWrapper(_ wrapper: RepoWrapper) {
        id = wrapper.id
        name = wrapper.name
        fullName = wrapper.fullName
        desc = wrapper.description
        url = wrapper.url
        stars = Int32(wrapper.stars)
        forks = Int32(wrapper.forks)
        language = wrapper.language
    }
}
