import Foundation

/// The expensive world art, generated off the main thread while the loading screen plays.
enum ArtCache {
    nonisolated(unsafe) static var ground: PixelCanvas?
    nonisolated(unsafe) static var water: [PixelCanvas]?

    /// Builds the map and water layers. Safe to call from a background task.
    static func warm() {
        if ground == nil { ground = MapArt.ground() }
        if water == nil { water = MapArt.waterFrames() }
    }
}
