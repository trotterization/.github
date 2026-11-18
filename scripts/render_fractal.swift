import Foundation
import Metal
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct Params {
    var width: UInt32
    var height: UInt32
    var phase: Float
    var padding: UInt32
}

let args = CommandLine.arguments
let width = Int(args.count > 1 ? args[1] : "720")!
let height = Int(args.count > 2 ? args[2] : "600")!
let count = Int(args.count > 3 ? args[3] : "112")!
let output = args.count > 4 ? args[4] : "/tmp/trotterization-fractal"
try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)
guard let device = MTLCreateSystemDefaultDevice(),
      let queue = device.makeCommandQueue() else { fatalError("Metal GPU unavailable") }
let source = try String(contentsOfFile: "scripts/fractal.metal", encoding: .utf8)
let library = try device.makeLibrary(source: source, options: nil)
let pipeline = try device.makeComputePipelineState(function: library.makeFunction(name: "render")!)
let buffer = device.makeBuffer(length: width*height*4, options: .storageModeShared)!
for i in 0..<count {
    var params = Params(width: UInt32(width), height: UInt32(height),
                        phase: Float(i)/Float(count)*2*Float.pi, padding: 0)
    let command = queue.makeCommandBuffer()!
    let encoder = command.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(pipeline)
    encoder.setBuffer(buffer, offset: 0, index: 0)
    encoder.setBytes(&params, length: MemoryLayout<Params>.size, index: 1)
    encoder.dispatchThreads(MTLSize(width: width, height: height, depth: 1),
                            threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
    encoder.endEncoding()
    command.commit()
    command.waitUntilCompleted()
    if let error = command.error { fatalError("\(error)") }
    let data = Data(bytes: buffer.contents(), count: width*height*4)
    let provider = CGDataProvider(data: data as CFData)!
    let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                        bytesPerRow: width*4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                        provider: provider, decode: nil, shouldInterpolate: false,
                        intent: .defaultIntent)!
    let url = URL(fileURLWithPath: output).appendingPathComponent(String(format: "%04d.png",i))
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    if i % 12 == 0 { print("Rendered \(i+1)/\(count)") }
}
