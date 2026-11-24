// Image sequence → H.264 MP4 (offline, AVFoundation). Usage: swift frames.swift <frame-dir> <fps> <out.mp4>
// Frames are encoded in name order at a constant frame rate; high bitrate keeps type crisp for Instagram re-encoding.
import AVFoundation
import CoreImage
import Foundation

let args = CommandLine.arguments
let dir = URL(fileURLWithPath: args[1]), fps = Int32(args[2])!, out = URL(fileURLWithPath: args[3])
let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
    .filter { ["jpg", "png"].contains($0.pathExtension) }.sorted { $0.lastPathComponent < $1.lastPathComponent }
try? FileManager.default.removeItem(at: out)
let width = 1080, height = 1920
let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 14_000_000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                      AVVideoMaxKeyFrameIntervalKey: Int(fps)]])
input.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA, kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: height])
writer.add(input)
writer.startWriting()
writer.startSession(atSourceTime: .zero)
let context = CIContext()
let space = CGColorSpace(name: CGColorSpace.sRGB)!
for (i, file) in files.enumerated() {
    let image = CIImage(contentsOf: file)!
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
    var buffer: CVPixelBuffer?
    CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
    context.render(image, to: buffer!, bounds: CGRect(x: 0, y: 0, width: width, height: height), colorSpace: space)
    adaptor.append(buffer!, withPresentationTime: CMTime(value: Int64(i), timescale: fps))
}
input.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
print("Encoded \(files.count) frames at \(fps) fps → \(out.lastPathComponent)")
