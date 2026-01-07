//
//  RaiderRouteApp.swift
//  RaiderRoute
//
//  Created by Mitchell Cohen on 1/7/26.
//

import SwiftData
import SwiftUI

@main
struct RaiderRouteApp: App {
  @StateObject private var dataPackLoader = DataPackLoader()

  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      RaidSession.self,
      LearnedProfile.self,
      Calibration.self,
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(dataPackLoader)
        .onAppear {
          dataPackLoader.load()
        }
    }
    .modelContainer(sharedModelContainer)
  }
}
