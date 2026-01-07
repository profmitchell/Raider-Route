import SwiftData
import SwiftUI

struct HistoryView: View {
  @Query(sort: \RaidSession.startedAt, order: .reverse) var sessions: [RaidSession]

  var body: some View {
    NavigationStack {
      List {
        if sessions.isEmpty {
          ContentUnavailableView(
            "No Raid History",
            systemImage: "clock.arrow.circlepath",
            description: Text("Complete a raid to see it here.")
          )
        } else {
          ForEach(sessions) { session in
            VStack(alignment: .leading) {
              Text(session.mapID.capitalized)
                .font(.headline)
              Text(session.startedAt.formatted())
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      }
      .navigationTitle("History")
    }
  }
}
