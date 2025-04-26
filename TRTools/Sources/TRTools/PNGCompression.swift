//
//  PNGCompression.swift
//  WAD Editor
//
//  Created by Evgenij Lutz on 24.04.25.
//

import Foundation


/// https://www.w3.org/TR/2003/REC-PNG-20031110/#11IDAT
func saveUncompressedPNG(width: Int, height: Int, pixels: [UInt8]) throws -> Data {
    var pngData = Data()

    // PNG Signature
    pngData.append(contentsOf: [137, 80, 78, 71, 13, 10, 26, 10])

    // IHDR Chunk
    func makeChunk(type: String, data: Data) -> Data {
        var chunk = Data()
        var length = UInt32(data.count).bigEndian
        chunk.append(Data(bytes: &length, count: 4))
        chunk.append(type.data(using: .ascii)!)
        chunk.append(data)
        let crc = crc32(type: type, data: data)
        chunk.append(contentsOf: withUnsafeBytes(of: crc.bigEndian, Array.init))
        return chunk
    }
    print(UInt32(width))
    print(UInt32(width).littleEndian)
    print(UInt32(width).bigEndian)

    var ihdr = Data()
    
    // Width
    do {
        var widthData = UInt32(width).bigEndian
        ihdr.append(Data(bytes: &widthData, count: 4))
    }
    
    // Height
    do {
        var heightData = UInt32(height).bigEndian
        ihdr.append(Data(bytes: &heightData, count: 4))
    }

    ihdr.append(8)     // bit depth
    ihdr.append(6)     // color type: RGBA
    ihdr.append(0)     // compression
    ihdr.append(0)     // filter
    ihdr.append(0)     // interlace
    pngData.append(makeChunk(type: "IHDR", data: ihdr))

    // Create uncompressed zlib stream with no compression
    var rawImageData = Data()
    for row in 0..<height {
        rawImageData.append(0) // filter byte per row
        let start = row * width * 4
        let end = start + width * 4
        rawImageData.append(contentsOf: pixels[start..<end])
    }

    // Create zlib header (fixed: CMF + FLG)
    var zlibStream = Data()
    zlibStream.append(0x78) // CMF
    zlibStream.append(0x01) // FLG: no compression, no preset

    // Wrap raw data as "no compression" DEFLATE blocks
    let blockSize = 65535
    var offset = 0
    while offset < rawImageData.count {
        let remaining = rawImageData.count - offset
        let chunkSize = min(remaining, blockSize)
        let isFinal = (offset + chunkSize) >= rawImageData.count
        zlibStream.append(isFinal ? 0x01 : 0x00) // BFINAL + BTYPE=00
        zlibStream.append(UInt8(chunkSize & 0xff))
        zlibStream.append(UInt8((chunkSize >> 8) & 0xff))
        let nlen = ~UInt16(chunkSize)
        zlibStream.append(UInt8(nlen & 0xff))
        zlibStream.append(UInt8((nlen >> 8) & 0xff))
        zlibStream.append(contentsOf: rawImageData[offset..<offset + chunkSize])
        offset += chunkSize
    }

    // Add zlib Adler-32 checksum
    let adler = adler32(data: rawImageData)
    zlibStream.append(contentsOf: withUnsafeBytes(of: adler.bigEndian, Array.init))

    pngData.append(makeChunk(type: "IDAT", data: zlibStream))
    pngData.append(makeChunk(type: "IEND", data: Data()))

    //try pngData.write(to: url)
    
    return pngData
}

// --- CRC32 and Adler32 ---

func crc32(type: String, data: Data) -> UInt32 {
    var crc: UInt32 = 0xffffffff
    let typeBytes = type.utf8
    for byte in typeBytes {
        crc = updateCRC(crc, byte)
    }
    for byte in data {
        crc = updateCRC(crc, byte)
    }
    return ~crc
}

fileprivate let table: [UInt32] = (0..<256).map { i -> UInt32 in
    var c = UInt32(i)
    for _ in 0..<8 {
        c = (c & 1 != 0) ? (0xedb88320 ^ (c >> 1)) : (c >> 1)
    }
    return c
}

func updateCRC(_ crc: UInt32, _ byte: UInt8) -> UInt32 {
    return table[Int((crc ^ UInt32(byte)) & 0xff)] ^ (crc >> 8)
}

func adler32(data: Data) -> UInt32 {
    var a: UInt32 = 1
    var b: UInt32 = 0
    for byte in data {
        a = (a + UInt32(byte)) % 65521
        b = (b + a) % 65521
    }
    return (b << 16) | a
}
