// Offline QR code for printed materials using macOS Core Image (no network, no package download).
// Usage: swift Marketing/qr.swift https://staygrubby.com Marketing/brand/qr-staygrubby.png
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
let filter = CIFilter(name: "CIQRCodeGenerator")!
filter.setValue(args[1].data(using: .utf8), forKey: "inputMessage")
filter.setValue("M", forKey: "inputCorrectionLevel")
let image = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 24, y: 24))
let context = CIContext()
let cg = context.createCGImage(image, from: image.extent)!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, cg, nil)
CGImageDestinationFinalize(dest)
print("Wrote \(args[2]) (\(cg.width)px)")
