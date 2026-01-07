//
//  ContentView.swift
//  RaiderRoute
//
//  Created by Mitchell Cohen on 1/7/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
  var body: some View {
    TabView {
      DataPackView()
        .tabItem {
          Label("DataPack", systemImage: "server.rack")
        }

      PlannerView()
        .tabItem {
          Label("Planner", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
        }

      MapView()
        .tabItem {
          Label("Map", systemImage: "map")
        }

      SearchView()
        .tabItem {
          Label("Search", systemImage: "magnifyingglass")
        }

      HistoryView()
        .tabItem {
          Label("History", systemImage: "clock")
        }
    }
  }
}

#Preview {
  ContentView()
    .environmentObject(DataPackLoader())
    .modelContainer(for: [RaidSession.self, LearnedProfile.self, Calibration.self], inMemory: true)
}
