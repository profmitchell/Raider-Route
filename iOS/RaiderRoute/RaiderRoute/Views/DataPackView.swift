import SwiftUI

struct DataPackView: View {
  @EnvironmentObject var loader: DataPackLoader

  var body: some View {
    NavigationStack {
      List {
        Section("Status") {
          if loader.isLoaded {
            Label("DataPack Loaded", systemImage: "checkmark.circle.fill")
              .foregroundStyle(.green)
          } else {
            Label("Loading / Missing Files", systemImage: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
          }
        }

        if let manifest = loader.manifest {
          Section("Manifest") {
            LabeledContent("Schema Version", value: "\(manifest.schemaVersion)")
            LabeledContent("Derived Files", value: "\(manifest.derivedFiles.count)")
          }
        }

        if !loader.missingFiles.isEmpty {
          Section("Missing Files") {
            ForEach(loader.missingFiles) { file in
              Text(file.filename)
                .foregroundStyle(.red)
                .font(.caption)
            }
          }
        }
      }
      .navigationTitle("DataPack")
    }
  }
}
