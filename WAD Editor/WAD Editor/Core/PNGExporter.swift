//
//  PNGExporter.swift
//  WAD Editor
//
//  Created by Evgenij Lutz on 13.04.25.
//

import Foundation

// Because of terrible performance of the PNG package in debug mode
#if (os(macOS) || os(iOS)) && DEBUG
import CoreGraphics
import ImageIO
#else
import PNG
#endif


func exportPNG(_ contents: [UInt8], width: Int, height: Int) throws -> Data {
#if (os(macOS) || os(iOS)) && DEBUG
    
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
    
    return mutableData as Data
#else
    
    // jesus fucking christ
    var pixels: [UInt32] = []
    let pixelCount = contents.count / 4
    for pixelIndex in 0 ..< pixelCount {
        let i = pixelIndex * 4
        let b = UInt32(contents[i + 0])
        let g = UInt32(contents[i + 1])
        let r = UInt32(contents[i + 2])
        let a = UInt32(contents[i + 3])
        let pixel = (b << 24) | (g << 16) | (r << 8) | (a << 0)
        pixels.append(pixel)
    }
    
    // Cast [UInt8] as [Uint32]
    let png = PNG.Image(
        packing: pixels,
        size: (width, height),
        layout: .init(
            format: .bgra8(palette: [], fill: nil)
            
            //format: .bgr8(
            //    palette: [],
            //    fill: nil,
            //    key: nil
            //)
        )
    )
    
    
    struct DataDestination: PNG.BytestreamDestination {
        var contents = Data()
        
        mutating func write(_ buffer: [UInt8]) -> Void? {
            contents.append(contentsOf: buffer)
        }
    }
    
    var pngData = DataDestination()
    do {
        try png.compress(stream: &pngData, level: 0)
    }
    catch {
        print(error)
        throw error
    }
    
    return pngData.contents
    
#endif
}
