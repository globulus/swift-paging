//
//  SwiftPagingDemoSwiftUIApp.swift
//  SwiftPagingDemoSwiftUI
//
//  Created by Gordan Glavaš on 07.06.2021..
//

import SwiftUI

@main
struct SwiftPagingDemoSwiftUIApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView(viewModel: ContentViewModel())
        }
    }
}
