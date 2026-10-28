import Foundation
import PDFKit

struct SourceSpec {
    let path: String
    let dates: [String]
}

let sources = [
    SourceSpec(
        path: "tmp/pdfs/sources/Scanned Document.pdf",
        dates: [
            "10-01-2025", "10-13-2025", "11-03-2025", "11-24-2025",
            "12-22-2025", "01-05-2026", "02-04-2026", "02-16-2026",
            "03-02-2026", "03-16-2026", "04-13-2026", "04-27-2026",
            "04-22-2026", "05-26-2026", "06-08-2026", "06-22-2026",
            "07-06-2026", "07-21-2026", "08-03-2026", "08-18-2026",
            "08-31-2026", "09-09-2026", "09-09-2026", "09-15-2026"
        ]
    ),
    SourceSpec(
        path: "tmp/pdfs/sources/Scanned Document 2.pdf",
        dates: [
            "09-23-2026", "09-29-2026", "10-07-2026", "10-14-2026",
            "10-28-2026"
        ]
    )
]

let outputDirectory = URL(fileURLWithPath: "output/pdf", isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
var seenDates: [String: Int] = [:]
var outputCount = 0

for sourceSpec in sources {
    let inputURL = URL(fileURLWithPath: sourceSpec.path)
    guard let source = PDFDocument(url: inputURL) else {
        throw NSError(domain: "DencoSplit", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not open \(sourceSpec.path)"])
    }
    guard source.pageCount == sourceSpec.dates.count else {
        throw NSError(domain: "DencoSplit", code: 2, userInfo: [NSLocalizedDescriptionKey: "Page/date count mismatch for \(sourceSpec.path): \(source.pageCount) pages, \(sourceSpec.dates.count) dates"])
    }

    for index in 0..<source.pageCount {
        guard let sourcePage = source.page(at: index),
              let pageData = sourcePage.dataRepresentation,
              let onePageSource = PDFDocument(data: pageData),
              let page = onePageSource.page(at: 0) else {
            throw NSError(domain: "DencoSplit", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not copy page \(index + 1) from \(sourceSpec.path)"])
        }

        page.rotation = (page.rotation + 270) % 360
        let output = PDFDocument()
        output.insert(page, at: 0)

        let date = sourceSpec.dates[index]
        let occurrence = (seenDates[date] ?? 0) + 1
        seenDates[date] = occurrence
        let suffix = occurrence == 1 ? "" : " (\(occurrence))"
        let filename = "Denco Service: \(date)\(suffix).pdf"
        let outputURL = outputDirectory.appendingPathComponent(filename)
        guard output.write(to: outputURL) else {
            throw NSError(domain: "DencoSplit", code: 4, userInfo: [NSLocalizedDescriptionKey: "Could not write \(filename)"])
        }
        outputCount += 1
        print("\(outputCount)\t\(sourceSpec.path)\tpage \(index + 1)\t\(filename)\trotation \(page.rotation)")
    }
}

print("WROTE\t\(outputCount)")
