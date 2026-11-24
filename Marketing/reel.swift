// Offline Reel encoder (macOS AVFoundation + Core Image; no downloads). Holds each rendered 1080x1920 frame for its
// duration with a slow push-in, crossfading between frames, and writes a silent H.264 MP4 (add music in Instagram).
// Usage: swift Marketing/reel.swift plan.json out.mp4   — plan: [{"image": "/abs/frame.png", "seconds": 1.6}, ...]
import AVFoundation
import CoreImage
import Foundation

struct Shot: Decodable { let image: String; let seconds: Double }

let args = CommandLine.arguments
let shots = try JSONDecoder().decode([Shot].self, from: Data(contentsOf: URL(fileURLWithPath: args[1])))
let out = URL(fileURLWithPath: args[2])
try? FileManager.default.removeItem(at: out)

let width = 1080, height = 1920, fps: Int32 = 30, fade = 8  // frames of crossfade (~0.27 s)
let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel]])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)

let context = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
let images = shots.map { CIImage(contentsOf: URL(fileURLWithPath: $0.image))! }
let extent = CGRect(x: 0, y: 0, width: width, height: height)

func pushed(_ image: CIImage, _ progress: Double) -> CIImage {
    // Gentle 0–2.5% push-in toward the centre over the shot.
    let scale = 1.0 + 0.025 * progress
    let t = CGAffineTransform(translationX: -Double(width) * (scale - 1) / 2, y: -Double(height) * (scale - 1) / 2).scaledBy(x: scale, y: scale)
    return image.transformed(by: t).cropped(to: extent)
}

var frameIndex: Int64 = 0
func append(_ image: CIImage) {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
    context.render(image, to: buffer!, bounds: extent, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    adaptor.append(buffer!, withPresentationTime: CMTime(value: frameIndex, timescale: fps))
    frameIndex += 1
}

for (i, shot) in shots.enumerated() {
    let count = max(Int(shot.seconds * Double(fps)), fade + 1)
    for f in 0..<count {
        let p = Double(f) / Double(count)
        var frame = pushed(images[i], p)
        if i + 1 < shots.count && f >= count - fade {
            let mix = Double(f - (count - fade) + 1) / Double(fade + 1)
            let next = pushed(images[i + 1], 0).applyingFilter("CIColorMatrix", parameters: ["inputAVector": CIVector(x: 0, y: 0, z: 0, w: mix)])
            frame = next.composited(over: frame)
        }
        append(frame)
    }
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print("Wrote \(out.path) (\(frameIndex) frames, \(Double(frameIndex) / Double(fps)) s)")
