#!/usr/bin/env swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let directory = CommandLine.arguments.dropFirst().first
  ?? "frontend/src-tauri/gen/apple/Assets.xcassets/AppIcon.appiconset"
let root = URL(fileURLWithPath: directory, isDirectory: true)
let files = try FileManager.default.contentsOfDirectory(
  at: root,
  includingPropertiesForKeys: nil
).filter { $0.pathExtension.lowercased() == "png" }

for file in files {
  guard
    let source = CGImageSourceCreateWithURL(file as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
  else {
    throw NSError(domain: "SynDayIcon", code: 1, userInfo: [
      NSLocalizedDescriptionKey: "Cannot read \(file.path)",
    ])
  }

  let rgbaBytesPerRow = image.width * 4
  var rgbaPixels = [UInt8](repeating: 0, count: rgbaBytesPerRow * image.height)
  guard let context = CGContext(
    data: &rgbaPixels,
    width: image.width,
    height: image.height,
    bitsPerComponent: 8,
    bytesPerRow: rgbaBytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else {
    throw NSError(domain: "SynDayIcon", code: 2, userInfo: [
      NSLocalizedDescriptionKey: "Cannot create RGB canvas for \(file.path)",
    ])
  }
  context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

  var rgbPixels = [UInt8]()
  rgbPixels.reserveCapacity(image.width * image.height * 3)
  for offset in stride(from: 0, to: rgbaPixels.count, by: 4) {
    rgbPixels.append(rgbaPixels[offset])
    rgbPixels.append(rgbaPixels[offset + 1])
    rgbPixels.append(rgbaPixels[offset + 2])
  }
  guard
    let provider = CGDataProvider(data: Data(rgbPixels) as CFData),
    let rgbImage = CGImage(
      width: image.width,
      height: image.height,
      bitsPerComponent: 8,
      bitsPerPixel: 24,
      bytesPerRow: image.width * 3,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
      provider: provider,
      decode: nil,
      shouldInterpolate: true,
      intent: .defaultIntent
    )
  else {
    throw NSError(domain: "SynDayIcon", code: 3, userInfo: [
      NSLocalizedDescriptionKey: "Cannot render \(file.path)",
    ])
  }

  let temporary = file.deletingLastPathComponent()
    .appendingPathComponent(".\(file.lastPathComponent).rgb")
  guard let destination = CGImageDestinationCreateWithURL(
    temporary as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
  ) else {
    throw NSError(domain: "SynDayIcon", code: 4, userInfo: [
      NSLocalizedDescriptionKey: "Cannot create \(temporary.path)",
    ])
  }
  CGImageDestinationAddImage(destination, rgbImage, nil)
  guard CGImageDestinationFinalize(destination) else {
    throw NSError(domain: "SynDayIcon", code: 5, userInfo: [
      NSLocalizedDescriptionKey: "Cannot encode \(file.path)",
    ])
  }
  try Data(contentsOf: temporary).write(to: file, options: .atomic)
  try FileManager.default.removeItem(at: temporary)
}

print("Converted \(files.count) iOS AppIcon PNGs to RGB without alpha.")
