import Foundation
import PDFKit
import AppKit

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "Render", code: 1)
    }
    try data.write(to: url)
}

let args = CommandLine.arguments
guard args.count >= 3 else {
    fputs("usage: render_pdf_pages.swift INPUT OUTPUT_DIR [MAX_PAGES]\n", stderr)
    exit(2)
}

let input = URL(fileURLWithPath: args[1])
let outputDir = URL(fileURLWithPath: args[2], isDirectory: true)
let maxPages = args.count >= 4 ? Int(args[3]) ?? Int.max : Int.max
let maxDimension = args.count >= 5 ? CGFloat(Double(args[4]) ?? 900) : 900
let startPage = max(1, args.count >= 6 ? Int(args[5]) ?? 1 : 1)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

guard let document = PDFDocument(url: input) else {
    fputs("failed to open PDF\n", stderr)
    exit(1)
}

print("pages=\(document.pageCount)")
let startIndex = min(document.pageCount, startPage - 1)
let endIndex = min(document.pageCount, startIndex + maxPages)
for index in startIndex..<endIndex {
    autoreleasepool {
        guard let page = document.page(at: index) else { return }
        let box = page.bounds(for: .mediaBox)
        let scale = min(1.0, maxDimension / max(box.width, box.height))
        let size = NSSize(width: max(1, box.width * scale), height: max(1, box.height * scale))
        let image = page.thumbnail(of: size, for: .mediaBox)
        let name = String(format: "page-%03d.png", index + 1)
        do {
            try savePNG(image, to: outputDir.appendingPathComponent(name))
            print("page=\(index + 1) rotation=\(page.rotation) size=\(Int(box.width))x\(Int(box.height)) file=\(name)")
        } catch {
            fputs("failed page \(index + 1): \(error)\n", stderr)
        }
    }
}
