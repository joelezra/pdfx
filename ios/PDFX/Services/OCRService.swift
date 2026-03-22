import Foundation
import Vision
import UIKit

@MainActor
class OCRService {
    func recognizeText(in image: UIImage) async -> [TextRegion] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let regions = observations.compactMap { observation -> TextRegion? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    return TextRegion(
                        text: candidate.string,
                        boundingBox: observation.boundingBox
                    )
                }
                continuation.resume(returning: regions)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}
