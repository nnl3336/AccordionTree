//
//  AccordionTreeApp.swift
//  AccordionTree
//
//  Created by Yuki Sasaki on 2025/08/29.
//

import SwiftUI

@main
struct AccordionTreeApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
