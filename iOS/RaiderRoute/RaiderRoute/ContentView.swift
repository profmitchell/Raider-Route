//
//  ContentView.swift
//  RaiderRoute
//
//  Created by Mitchell Cohen on 1/7/26.
//

import SwiftData
import SwiftUI

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

      ItemBrowserView()
        .tabItem {
          Label("Catalog", systemImage: "magnifyingglass")
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
    .environmentObject(UserDataStore())
    .modelContainer(for: [RaidSession.self, LearnedProfile.self, Calibration.self], inMemory: true)
}
