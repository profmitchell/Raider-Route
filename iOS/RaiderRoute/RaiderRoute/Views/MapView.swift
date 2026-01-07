import SwiftData
import SwiftUI

struct MapView: View {
  @EnvironmentObject var loader: DataPackLoader
  @Query var calibrations: [Calibration]

  @State private var selectedMapID: String = "dam"  // Default
  @State private var showCalibrationWizard = false

  // Layers
  @State private var showSpawns = true
  @State private var showContainers = true
  @State private var showArcs = true

  var availableMaps: [String] {
    // Parse from manifest or hardcode known ones
    return ["dam", "spaceport", "buried-city", "blue-gate"]
  }

  var currentCalibration: Calibration? {
    calibrations.first(where: { $0.mapID == selectedMapID })
  }

  var body: some View {
    NavigationStack {
      VStack {
        // Map Image Area
        GeometryReader { geo in
          ZStack {
            if let cal = currentCalibration, let uiImage = loadImage(filename: cal.imageFilename) {
              Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .overlay {
                  // Overlay Points
                  MapOverlayView(
                    mapID: selectedMapID,
                    calibration: cal,
                    showSpawns: showSpawns,
                    showContainers: showContainers,
                    showArcs: showArcs,
                    imageSize: uiImage.size
                  )
                }
            } else {
              // Placeholder / Uncalibrated
              ContentUnavailableView {
                Label("Map Not Calibrated", systemImage: "map.fill")
              } description: {
                Text("Select 'Calibrate' to set up this map.")
              }
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }

        // Controls
        VStack {
          Picker("Map", selection: $selectedMapID) {
            ForEach(availableMaps, id: \.self) { map in
              Text(map.capitalized).tag(map)
            }
          }
          .pickerStyle(.segmented)
          .padding()

          HStack {
            Toggle("Spawns", isOn: $showSpawns)
            Toggle("Loot", isOn: $showContainers)
            Toggle("Arcs", isOn: $showArcs)
          }
          .padding(.horizontal)
          .font(.caption)

          if currentCalibration == nil {
            Button("Calibrate Now") {
              showCalibrationWizard = true
            }
            .buttonStyle(.borderedProminent)
            .padding()
          }
        }
        .background(.thinMaterial)
      }
      .navigationTitle("Map")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Recalibrate") {
            showCalibrationWizard = true
          }
        }
      }
      .sheet(isPresented: $showCalibrationWizard) {
        CalibrationWizardView(mapID: selectedMapID, isPresented: $showCalibrationWizard)
      }
    }
  }

  func loadImage(filename: String) -> UIImage? {
    // Try bundled first
    if let img = UIImage(named: filename) { return img }
    // Try documents (UserStorage logic omitted for brevity, fallback to bundled check)
    // Check our embedded maps path
    let nameWithoutExt = (filename as NSString).deletingPathExtension
    return UIImage(
      contentsOfFile: Bundle.main.path(
        forResource: nameWithoutExt, ofType: "png", inDirectory: "DataPack/maps") ?? "")
  }
}

struct MapOverlayView: View {
  let mapID: String
  let calibration: Calibration
  let showSpawns: Bool
  let showContainers: Bool
  let showArcs: Bool
  let imageSize: CGSize

  @EnvironmentObject var loader: DataPackLoader

  var nodes: [CompactMapNode] {
    loader.loadMapNodes(mapID: mapID)
  }

  var body: some View {
    GeometryReader { geo in
      // Must project lat/lng -> image pixels -> view pixels
      // Calibration transform gives lat/lng -> IMAGE pixels (x,y)
      // We need to scale that to the current view size (geo.size) based on aspect fit

      let scale = min(geo.size.width / imageSize.width, geo.size.height / imageSize.height)
      let xOffset = (geo.size.width - imageSize.width * scale) / 2
      let yOffset = (geo.size.height - imageSize.height * scale) / 2

      ForEach(nodes) { node in
        if shouldShow(node) {
          let pt = CalibrationLogic.project(
            lat: node.lat, lng: node.lng, transform: calibration.transform)
          // Transform image pt -> view pt
          let viewX = pt.x * scale + xOffset
          let viewY = pt.y * scale + yOffset

          Circle()
            .fill(colorFor(node))
            .frame(width: 6, height: 6)
            .position(x: viewX, y: viewY)
        }
      }
    }
  }

  func shouldShow(_ node: CompactMapNode) -> Bool {
    if node.subcategory == "player_spawn" { return showSpawns }
    if node.category == "containers" { return showContainers }
    if node.category == "arc" { return showArcs }
    return false
  }

  func colorFor(_ node: CompactMapNode) -> Color {
    if node.subcategory == "player_spawn" { return .green }
    if node.category == "containers" { return .yellow }
    if node.category == "arc" { return .red }
    return .gray
  }
}
