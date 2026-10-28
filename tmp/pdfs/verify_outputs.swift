import Foundation
import PDFKit
import AppKit

let directory = URL(fileURLWithPath: "output/pdf", isDirectory: true)
let files = try FileManager.default.contentsOfDirectory(
    at: directory,
    includingPropertiesForKeys: nil,
    options: [.skipsHiddenFiles]
).filter { $0.pathExtension.lowercased() == "pdf" }.sorted { $0.lastPathComponent < $1.lastPathComponent }

guard files.count == 29 else {
    throw NSError(domain: "Verify", code: 1, userInfo: [NSLocalizedDescriptionKey: "Expected 29 PDFs, found \(files.count)"])
}

let columns = 4
let cellWidth: CGFloat = 520
let cellHeight: CGFloat = 350
let rows = Int(ceil(Double(files.count) / Double(columns)))
let canvas = NSImage(size: NSSize(width: CGFloat(columns) * cellWidth, height: CGFloat(rows) * cellHeight))
canvas.lockFocus()
NSColor.white.setFill()
NSRect(origin: .zero, size: canvas.size).fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let textAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 17, weight: .medium),
    .foregroundColor: NSColor.black,
    .paragraphStyle: paragraph
]

for (index, file) in files.enumerated() {
    guard let document = PDFDocument(url: file), document.pageCount == 1, let page = document.page(at: 0) else {
        throw NSError(domain: "Verify", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid one-page PDF: \(file.lastPathComponent)"])
    }
    guard page.rotation == 270 else {
        throw NSError(domain: "Verify", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unexpected rotation \(page.rotation): \(file.lastPathComponent)"])
    }

    let row = index / columns
    let column = index % columns
    let x = CGFloat(column) * cellWidth
    let y = canvas.size.height - CGFloat(row + 1) * cellHeight
    let thumbnail = page.thumbnail(of: NSSize(width: 480, height: 280), for: .mediaBox)
    let imageRect = NSRect(x: x + 20, y: y + 55, width: cellWidth - 40, height: cellHeight - 75)
    thumbnail.draw(in: imageRect, from: .zero, operation: .copy, fraction: 1)
    let labelRect = NSRect(x: x + 8, y: y + 12, width: cellWidth - 16, height: 34)
    file.deletingPathExtension().lastPathComponent.draw(in: labelRect, withAttributes: textAttributes)
    print("OK\t\(file.lastPathComponent)\tpages=1\trotation=\(page.rotation)\tsize=\(Int(page.bounds(for: .mediaBox).width))x\(Int(page.bounds(for: .mediaBox).height))")
}

canvas.unlockFocus()
guard let tiff = canvas.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "Verify", code: 4)
}
let contactSheet = URL(fileURLWithPath: "tmp/pdfs/output-contact-sheet.png")
try png.write(to: contactSheet)
print("CONTACT_SHEET\t\(contactSheet.path)")
