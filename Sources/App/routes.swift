import Vapor
import AppKit
import Vision

struct FloorPlanAnalysis: Content {
    let totalArea: Double
    let roomCount: Int
    let debugText: String
}

func routes(_ app: Application) throws {
    app.post("analyze-floor-plan") { req -> EventLoopFuture<FloorPlanAnalysis> in
        struct Input: Content {
            var image: Data
        }
        
        let input = try req.content.decode(Input.self)
        
        guard let image = NSImage(data: input.image),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw Abort(.badRequest, reason: "Invalid image data")
        }
        
        return req.eventLoop.future().flatMapThrowing { () -> FloorPlanAnalysis in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.customWords = ["м²", "m²", "кв.м", "кв. м"]
            request.minimumTextHeight = 0.01
            
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            
            guard let observations = request.results else {
                throw Abort(.internalServerError, reason: "Failed to process image")
            }
            
            let recognizedStrings = observations.compactMap { $0.topCandidates(1).first?.string }
            return processRecognizedText(recognizedStrings)
        }
    }
}

func processRecognizedText(_ strings: [String]) -> FloorPlanAnalysis {
    var numbers: [Double] = []
    var debugText = "Extracted numbers:\n"

    for string in strings {
        if let number = extractNumber(from: string) {
            if number <= 500 {
                numbers.append(number)
                debugText += "\(number)\n"
            }
        }
    }

    numbers.sort(by: >)
    debugText += "\nSorted numbers:\n\(numbers.map { String($0) }.joined(separator: ", "))"

    let totalArea: Double
    let roomCount: Int

    if numbers.count > 1 {
        let largestNumber = numbers[0]
        let sumOfOthers = numbers.dropFirst().reduce(0, +)

        if abs(largestNumber - sumOfOthers) < 0.2 * largestNumber {
            totalArea = largestNumber
            roomCount = numbers.count - 1
            debugText += "\n\nLargest number (\(largestNumber)) is close to sum of others (\(sumOfOthers))"
        } else {
            totalArea = numbers.reduce(0, +)
            roomCount = numbers.count
            debugText += "\n\nLargest number (\(largestNumber)) is not close to sum of others (\(sumOfOthers))"
        }
    } else if numbers.count == 1 {
        totalArea = numbers[0]
        roomCount = 1
        debugText += "\n\nOnly one number found"
    } else {
        totalArea = 0
        roomCount = 0
        debugText += "\n\nNo valid numbers found"
    }

    return FloorPlanAnalysis(totalArea: totalArea, roomCount: roomCount, debugText: debugText)
}

func extractNumber(from string: String) -> Double? {
    let pattern = "\\d+(?:[.,]\\d+)?"
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(string.startIndex..., in: string)
    
    if let match = regex.firstMatch(in: string, range: range),
       let matchRange = Range(match.range, in: string) {
        let numberString = string[matchRange]
            .replacingOccurrences(of: ",", with: ".")
        return Double(numberString)
    }
    return nil
}


