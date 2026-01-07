import SwiftData
import SwiftUI

struct CalibrationWizardView: View {
  let mapID: String
  @Binding var isPresented: Bool
  @EnvironmentObject var userData: UserDataStore
  @EnvironmentObject var dataPack: DataPackLoader
  @Environment(\.modelContext) var modelContext

  @State private var image: UIImage?
  @State private var anchors: [CalibrationAnchor] = []
  @State private var selectedNodeId: String?
  @State private var zoomScale: CGFloat = 1.0

  // Default maps provided?
  var bundledMapImage: UIImage? {
    // Try loading from bundle if we copied them
    // Filename conventions: dam.png, spaceport.png etc matching mapID
    return UIImage(named: "\(mapID).png")
      ?? UIImage(
        contentsOfFile: Bundle.main.path(
          forResource: mapID, ofType: "png", inDirectory: "DataPack/maps") ?? "")
  }

  var body: some View {
    NavigationStack {
      VStack {
        if let img = image {
          GeometryReader { geo in
            Image(uiImage: img)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .overlay {
                CalibrationOverlay(anchors: anchors)
              }
              .gesture(
                SpatialTapGesture().onEnded { event in
                  handleTap(at: event.location, in: geo.size, imageSize: img.size)
                }
              )
          }
        } else {
          ContentUnavailableView {
            Label("No Map Image", systemImage: "photo")
          } description: {
            Text("Please import a map image to begin.")
          } actions: {
            Button("Load Default / Import") {
              // Quick hack: load bundled if available, else picker (omitted for brevity)
              if let bundled = bundledMapImage {
                self.image = bundled
              }
            }
          }
        }

        // Controls
        VStack {
          Text("Tap map to place anchor for: \(selectedNodeName)")
            .font(.caption)

          TextField("Search Anchors (e.g. Exit)", text: $searchText)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal)

          ScrollView(.horizontal) {
            HStack {
              ForEach(suggestedAnchors, id: \.id) { node in
                Button {
                  selectedNodeId = node.id
                } label: {
                  Text(nodeName(node))
                    .padding(8)
                    .background(selectedNodeId == node.id ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(selectedNodeId == node.id ? .white : .primary)
                    .cornerRadius(8)
                }
              }
            }
          }
          .padding()

          Button("Auto Calibrate (Fit to Image)") {
            autoCalibrate()
          }
          .padding(.bottom, 8)

          Button("Save Calibration") {
            save()
          }
          .disabled(anchors.count < 3)
        }
        .background(.thinMaterial)
      }
      .navigationTitle("Calibrate: \(mapID)")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { isPresented = false }
        }
      }
    }
  }

  @State private var searchText = ""

  var suggestedAnchors: [CompactMapNode] {
    let nodes = dataPack.loadMapNodes(mapID: mapID)

    // Filter for likely landmarks
    let landmarks = nodes.filter { node in
      let sub = node.subcategory?.lowercased() ?? ""
      let cat = node.category?.lowercased() ?? ""

      // Must have a name or be a significant type
      let hasName = (node.instanceName != nil && !node.instanceName!.isEmpty)
      let isSignificant =
        sub.contains("extraction") || sub.contains("hatch") || sub.contains("locked_room")
        || sub.contains("tower") || cat == "locations"

      return hasName || isSignificant
    }

    let sorted = landmarks.sorted { a, b in
      // extractions first
      let aExt = a.subcategory?.contains("extraction") ?? false
      let bExt = b.subcategory?.contains("extraction") ?? false
      if aExt != bExt { return aExt }

      // then named
      let aName = a.instanceName ?? ""
      let bName = b.instanceName ?? ""
      return aName < bName
    }

    if searchText.isEmpty {
      return Array(sorted.prefix(20))
    } else {
      return sorted.filter { nodeName($0).localizedCaseInsensitiveContains(searchText) }
    }
  }

  var selectedNodeName: String {
    if let id = selectedNodeId, let node = suggestedAnchors.first(where: { $0.id == id }) {
      return nodeName(node)
    }
    return "Select a node below"
  }

  func nodeName(_ node: CompactMapNode) -> String {
    return node.instanceName ?? node.subcategory ?? node.category ?? node.id
  }

  func handleTap(at point: CGPoint, in viewSize: CGSize, imageSize: CGSize) {
    guard let nodeId = selectedNodeId, let node = suggestedAnchors.first(where: { $0.id == nodeId })
    else { return }

    // Convert view point to image coordinate space
    // This is tricky without knowing exact aspect fit rect.
    // For MVP, assuming aspect fit centered.

    let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
    let scaledWidth = imageSize.width * scale
    let scaledHeight = imageSize.height * scale
    let xOffset = (viewSize.width - scaledWidth) / 2
    let yOffset = (viewSize.height - scaledHeight) / 2

    let imgX = (point.x - xOffset) / scale
    let imgY = (point.y - yOffset) / scale

    if imgX >= 0 && imgX <= imageSize.width && imgY >= 0 && imgY <= imageSize.height {
      // Remove existing for this node if any
      anchors.removeAll { $0.nodeId == nodeId }

      anchors.append(
        CalibrationAnchor(
          nodeId: nodeId,
          lat: node.lat,
          lng: node.lng,
          x: imgX,
          y: imgY
        ))

      // Auto select next?
    }
  }

  func save() {
    guard let transform = CalibrationLogic.solve(anchors: anchors) else {
      print("Failed to solve transform")
      return
    }

    let calibration = Calibration(
      mapID: mapID,
      imageFilename: "\(mapID).png",  // assuming default for now
      transform: transform,
      anchors: anchors
    )
    // SwiftData save
    modelContext.insert(calibration)
    isPresented = false
  }

  func autoCalibrate() {
    guard let bounds = dataPack.getMapBounds(mapID: mapID), let img = image else { return }

    // Heuristic: Map 0,0 image to Bounds TopLeft, etc.
    // Game Coordinates often: X=Horizontal (Lng?), Y=Vertical (Lat?) or inverted.
    // Usually Lat/Lng from game data:
    // Lat = Y (vertical), Lng = X (horizontal)
    // Check data:
    // Bounds: minLat..maxLat, minLng..maxLng
    // Image: 0..W, 0..H

    // We need 3 points.
    // Point 1: Top-Left (Min X, Min Y) -> (minLng, maxLat) [If Y is Up]
    // Wait, standard image: (0,0) is top-left.
    // Game coords: Usually Y grows up? Or down?
    // Let's assume standard map: Lng=X (Left->Right), Lat=Y (Bottom->Top).

    // So:
    // Image (0,0) [Top-Left] -> (minLng, maxLat)
    // Image (W,H) [Bottom-Right] -> (maxLng, minLat)
    // Image (0,H) [Bottom-Left] -> (minLng, minLat)

    let w = img.size.width
    let h = img.size.height

    anchors = [
      CalibrationAnchor(nodeId: "auto-tl", lat: bounds.maxLat, lng: bounds.minLng, x: 0, y: 0),
      CalibrationAnchor(nodeId: "auto-br", lat: bounds.minLat, lng: bounds.maxLng, x: w, y: h),
      CalibrationAnchor(nodeId: "auto-bl", lat: bounds.minLat, lng: bounds.minLng, x: 0, y: h),
    ]

    save()
  }
}

struct CalibrationOverlay: View {
  let anchors: [CalibrationAnchor]
  var body: some View {
    // Draw points on image?
    // Actually, this overlay needs to be in image-space logic or handled in the parent ZStack logic to match scaling
    // For simplicity, omitting visual indicators on the image in this snippet,
    // effectively relying on the user trusting their tap.
    EmptyView()
  }
}

// Helper model needs to be exposed in Models or here?
// Assuming CompactMapNode is defined in DataPackLoader or similar.
// Since it wasn't defined yet, let's mock it inside DataPackLoader or Models.
