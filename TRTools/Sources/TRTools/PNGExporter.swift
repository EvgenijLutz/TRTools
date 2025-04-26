//
//  PNGExporter.swift
//  WAD Editor
//
//  Created by Evgenij Lutz on 13.04.25.
//

import Foundation

// Use Apple's frameworks to compress png if available
#if (os(macOS) || os(iOS)) //&& DEBUG
import CoreGraphics
import ImageIO
#endif


fileprivate func serializePng(_ data: Data) throws {
    do {
        let exportUrl = FileManager.default.temporaryDirectory.appending(component: "export.png")
        try data.write(to: exportUrl)
        print("Export succeeded: \(exportUrl)")
    }
    catch {
        print("Could not export: \(error)")
    }
}


func exportPNG(_ contents: [UInt8], width: Int, height: Int) throws -> Data {
#if (os(macOS) || os(iOS)) //&& DEBUG
    
    // jesus fucking christ
    var pixels: [UInt8] = []
    let pixelCount = contents.count / 4
    for pixelIndex in 0 ..< pixelCount {
        let i = pixelIndex * 4
        let b = contents[i + 0]
        let g = contents[i + 1]
        let r = contents[i + 2]
        let a = contents[i + 3]
        pixels.append(contentsOf: [r, g, b, a])
    }
    
    let contentsData = Data(pixels) as CFData
    guard let provider = CGDataProvider(data: contentsData) else {
        throw WADExportError.corruptedImageData
    }
    
    //let c = kCGImageAlphaNone
    guard let image = CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: 4 * width,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: [.init(rawValue: CGImageAlphaInfo.last.rawValue)],
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    ) else {
        throw WADExportError.corruptedImageData
    }
    
    guard let mutableData = CFDataCreateMutable(kCFAllocatorDefault, 0) else {
        throw WADExportError.corruptedImageData
    }
    
    guard let consumer = CGDataConsumer(data: mutableData) else {
        throw WADExportError.corruptedImageData
    }
    
    guard let destination = CGImageDestinationCreateWithDataConsumer(consumer, "public.png" as CFString, 1, nil) else {
        throw WADExportError.corruptedImageData
    }
    
    CGImageDestinationAddImage(destination, image, nil)
    
    let finalized = CGImageDestinationFinalize(destination)
    guard finalized else {
        throw WADExportError.corruptedImageData
    }
    
//#if DEBUG
//    try serializePng(mutableData as Data)
//#endif
    
    return mutableData as Data
#else
    
    return try saveUncompressedPNG(width: width, height: height, pixels: pixels)
    
#endif
}
