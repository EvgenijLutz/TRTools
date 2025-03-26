//
//  WAD IO.swift
//  WAD Editor
//
//  Created by Evgenij Lutz on 15.03.25.
//

import Foundation
import WADKit


struct DataReader {
    enum DataReaderError: Error {
        case strangeDataSize(offset: Int, type: Any.Type)
        case indexOutOfRange(offset: Int, endOffset: Int, type: Any.Type)
        case unwrapMemoryError(offset: Int, endOffset: Int, type: Any.Type)
        case other(_ message: String)
    }
    
    let data: Data
    private(set) var offset: Int
    
    
    init(_ data: Data) {
        self.data = data
        self.offset = 0
    }
    
    mutating func reset() {
        offset = 0
    }
    
    mutating func set<SomeType: BinaryInteger>(_ newOffset: SomeType) {
        offset = Int(newOffset)
    }
    
    mutating func skip<SomeType: BinaryInteger>(_ bytesToSkip: SomeType) {
        let numBytes = Int(bytesToSkip)
        offset += numBytes
    }
    
    mutating func back(_ bytesToGoBack: Int) {
        offset -= bytesToGoBack
    }
    
    mutating func read<SomeType>() throws -> SomeType {
        let length = MemoryLayout<SomeType>.size
        guard length > 0 else {
            throw DataReaderError.strangeDataSize(offset: offset, type: SomeType.self)
        }
        
        let endIndex = offset + length
        guard offset >= 0 && endIndex <= data.count else {
            throw DataReaderError.indexOutOfRange(offset: offset, endOffset: endIndex, type: SomeType.self)
        }
        
        let value = try data[data.startIndex.advanced(by: offset) ..< data.startIndex.advanced(by: endIndex)].withUnsafeBytes {
            guard let value = $0.baseAddress?.loadUnaligned(as: SomeType.self) else {
                throw DataReaderError.unwrapMemoryError(offset: offset, endOffset: endIndex, type: SomeType.self)
            }
            
            return value
        }
        
        offset = endIndex
        return value
    }
    
    mutating func readData<Integer: BinaryInteger>(ofLength length: Integer) throws -> Data {
        guard length >= 0 else {
            throw DataReaderError.strangeDataSize(offset: offset, type: Data.self)
        }
        
        if length == 0 {
            return Data()
        }
        
        let endIndex = offset + Int(length)
        guard offset >= 0 && endIndex <= data.count else {
            throw DataReaderError.indexOutOfRange(offset: offset, endOffset: endIndex, type: Data.self)
        }
        
        let value = data[data.startIndex.advanced(by: offset) ..< data.startIndex.advanced(by: endIndex)]
        
        offset = endIndex
        return value
    }
}


struct DataWriter {
    private(set) var data = Data()
    
    mutating func write<SomeType: BinaryInteger>(_ value: SomeType) {
        withUnsafePointer(to: value) { pointer in
            data.append(Data(bytes: pointer, count: MemoryLayout<SomeType>.size))
        }
    }
    
    mutating func write<SomeType: BinaryFloatingPoint>(_ value: SomeType) {
        withUnsafePointer(to: value) { pointer in
            data.append(Data(bytes: pointer, count: MemoryLayout<SomeType>.size))
        }
    }
    
    mutating func write(_ value: Data) {
        data.append(value)
    }
    
    mutating func skip<SomeType: BinaryInteger>(_ bytesToSkip: SomeType) {
        let numBytes = Int(bytesToSkip)
        guard numBytes > 0 else {
            return
        }
        
        data.append(Data(capacity: numBytes))
    }
}



extension WAD {
    func exportGLTFAnimation(_ animationIndex: Int, of movableIndex: Int) async throws -> Data {
        let convertData = await generateCombinedTexturePages(pagesPerRow: 8)
        let vertexBuffers = try await meshes[31].generateVertexBuffers(in: self, withRemappedTexturePages: convertData.remapInfo)
        
        var buffers: [GLTFBuffer] = []
        var bufferViews: [GLTFBufferView] = []
        var accessors: [GLTFAccessor] = []
        var meshes: [GLTFMesh] = []
        var nodes: [GLTFNode] = []
        
        
        var binaryData = Data()
        
        
        for vertexBuffer in vertexBuffers {
            var reader = DataReader(vertexBuffer.vertexBuffer)
            let stride = vertexBuffer.lightingType.stride
            
            var attributes: [String: Int] = [:]
            
            // Vertices
            do {
                var writer = DataWriter()
                
                for i in 0 ..< vertexBuffer.numVertices {
                    reader.set(i * stride)
                    let x: Float = try reader.read()
                    let y: Float = try reader.read()
                    let z: Float = try reader.read()
                    
                    writer.write(x)
                    writer.write(y)
                    writer.write(z)
                }
                
                attributes["POSITION"] = accessors.count
                
                accessors.append(.init(
                    bufferView: bufferViews.count,
                    byteOffset: 0,
                    componentType: .float,
                    count: vertexBuffer.numVertices /*/ 3*/,
                    type: .vec3
                ))
                
                bufferViews.append(.init(
                    buffer: 0,
                    byteOffset: binaryData.count,
                    byteLength: writer.data.count,
                    byteStride: 12
                ))
                
                binaryData.append(writer.data)
            }
            
            // Normals
            if vertexBuffer.lightingType == .normals || vertexBuffer.lightingType == .normalsWithWeights {
                var writer = DataWriter()
                
                for i in 0 ..< vertexBuffer.numVertices {
                    reader.set(i * stride + 20)
                    let x: Float = try reader.read()
                    let y: Float = try reader.read()
                    let z: Float = try reader.read()
                    
                    writer.write(x)
                    writer.write(y)
                    writer.write(z)
                }
                
                attributes["NORMAL"] = accessors.count
                
                accessors.append(.init(
                    bufferView: bufferViews.count,
                    byteOffset: 0,
                    componentType: .float,
                    count: vertexBuffer.numVertices /*/ 3*/,
                    type: .vec3
                ))
                
                bufferViews.append(.init(
                    buffer: 0,
                    byteOffset: binaryData.count,
                    byteLength: writer.data.count,
                    byteStride: 12
                ))
                
                binaryData.append(writer.data)
            }
            
            
            
            nodes.append(.init(
                mesh: meshes.count,
                rotation: [0,0,0,1],
                scale: [2,2,2],
                translation: [0,0,0]
            ))
            
            meshes.append(.init(
                primitives: [
                    .init(
                        attributes: attributes,
                        mode: .triangles
                    )
                ]
            ))
        }
        
        
        buffers.append(.init(
            byteLength: binaryData.count
        ))
        
        
        var skins: [GLTFSkin] = []
        skins.append(.init(
            skeleton: 0,
            joints: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        ))
        
        
        var animations: [GLTFAnimation] = []
        animations.append(.init(
            channels: [
                .init(
                    sampler: 0,
                    target: .init(
                        node: 0,
                        path: .rotation
                    )
                )
            ],
            samplers: [
                .init(
                    input: 0,
                    interpolation: .linear,
                    output: 1
                )
            ]
        ))
        
        
        let asset = GLTFAsset(generator: "WAD Editor 1.0.0-alpha1", version: "2.0")
        let gltf = GLTF(accessors: accessors, asset: asset, buffers: buffers, bufferViews: bufferViews, meshes: meshes, nodes: nodes)
        let library = GLTFLibrary(gltf: gltf, binaryChunks: [binaryData])
        
        return try await library.exportToGLB()
    }
}
