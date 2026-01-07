//
//  Item.swift
//  RaiderRoute
//
//  Created by Mitchell Cohen on 1/7/26.
//

import Foundation
import SwiftData

// MARK: - Persistent User Data

@Model
final class RaidSession {
  var id: UUID
  var mapID: String
  var spawnNodeId: String?
  var plannedWaypoints: [String]  // Node IDs
  var startedAt: Date
  var endedAt: Date?
  var rating: Int16?  // 1-5
  var tags: [String]
  var note: String?

  init(mapID: String, spawnNodeId: String? = nil, plannedWaypoints: [String] = []) {
    self.id = UUID()
    self.mapID = mapID
    self.spawnNodeId = spawnNodeId
    self.plannedWaypoints = plannedWaypoints
    self.startedAt = Date()
    self.tags = []
  }
}

@Model
final class LearnedProfile {
  @Attribute(.unique) var mapID: String
  var nodeBonuses: [String: Double]  // NodeId -> Bonus
  var nodePenalties: [String: Double]  // NodeId -> Penalty
  var edgePenalties: [String: Double]  // "from|to" -> Penalty

  init(mapID: String) {
    self.mapID = mapID
    self.nodeBonuses = [:]
    self.nodePenalties = [:]
    self.edgePenalties = [:]
  }
}

@Model
final class Calibration {
  @Attribute(.unique) var mapID: String
  var imageFilename: String
  var transform: [Double]  // a,b,c,d,tx,ty
  var anchors: [CalibrationAnchor]
  var createdAt: Date

  init(mapID: String, imageFilename: String, transform: [Double], anchors: [CalibrationAnchor]) {
    self.mapID = mapID
    self.imageFilename = imageFilename
    self.transform = transform
    self.anchors = anchors
    self.createdAt = Date()
  }
}

struct CalibrationAnchor: Codable {
  var nodeId: String
  var lat: Double
  var lng: Double
  var x: Double
  var y: Double
}
