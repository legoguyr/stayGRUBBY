import Foundation
import PDFKit
import AppKit
import Vision
import ImageIO

struct OCRLine {
    let text: String
    let confidence: Float
    let box: CGRect
}

func renderPage(_ page: PDFPage, maxDimension: CGFloat = 1400) -> CGImage? {
    let bounds = page.bounds(for: .mediaBox)
    let scale = min(1.0, maxDimension / max(bounds.width, bounds.height))
    let width = max(1, Int(bounds.width * scale))
    let height = max(1, Int(bounds.height * scale))
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.saveGState()
    context.scaleBy(x: scale, y: scale)
    page.draw(with: .mediaBox, to: context)
    context.restoreGState()
    return context.makeImage()
}

func recognize(_ image: CGImage, orientation: CGImagePropertyOrientation) throws -> [OCRLine] {
    let request = VNRecognizeTextRequest()
    request.usesCPUOnly = true
    request.recognitionLevel = .fast
    request.usesLanguageCorrection = false
    let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
    try handler.perform([request])
    let observations = request.results ?? []
    return observations.compactMap { observation in
        guard let candidate = observation.topCandidates(1).first else { return nil }
        return OCRLine(text: candidate.string, confidence: candidate.confidence, box: observation.boundingBox)
    }.sorted {
        let dy = abs($0.box.midY - $1.box.midY)
        if dy > 0.015 { return $0.box.midY > $1.box.midY }
        return $0.box.minX < $1.box.minX
    }
}

let args = CommandLine.arguments
guard args.count >= 2 else {
    fputs("usage: ocr_pdf_dates.swift INPUT [START_PAGE] [END_PAGE]\n", stderr)
    exit(2)
}

let input = URL(fileURLWithPath: args[1])
let startPage = max(1, args.count >= 3 ? Int(args[2]) ?? 1 : 1)
guard let document = PDFDocument(url: input) else {
    fputs("failed to open PDF\n", stderr)
    exit(1)
}
let endPage = min(document.pageCount, args.count >= 4 ? Int(args[3]) ?? document.pageCount : document.pageCount)

print("DOCUMENT\t\(input.lastPathComponent)\tPAGES\t\(document.pageCount)")
for pageNumber in startPage...endPage {
    autoreleasepool {
        guard let page = document.page(at: pageNumber - 1), let image = renderPage(page) else {
            print("PAGE\t\(pageNumber)\tERROR\trender")
            return
        }
        do {
            let lines = try recognize(image, orientation: .left)
            print("PAGE\t\(pageNumber)\tROTATE\tCCW90")
            for line in lines {
                let clean = line.text.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ")
                print("LINE\t\(String(format: "%.3f", line.confidence))\t\(clean)")
            }
            print("ENDPAGE")
        } catch {
            let ns = error as NSError
            print("PAGE\t\(pageNumber)\tERROR\t\(String(reflecting: error))\tDOMAIN\t\(ns.domain)\tCODE\t\(ns.code)\tINFO\t\(ns.userInfo)")
        }
    }
}
