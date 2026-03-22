import Foundation

struct TextRegion: Identifiable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect
    var editedText: String?

    var displayText: String {
        editedText ?? text
    }
}
