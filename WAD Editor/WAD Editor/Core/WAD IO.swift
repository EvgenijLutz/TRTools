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
    func exportGLTFAnimation(_ animationIndex: Int, of modelTyle: TR4ObjectType) async throws -> Data {
        guard let model = findModel(modelTyle) else {
            throw WADError.modelNotFound
        }
        
        guard let rootJoint = model.rootJoint else {
            throw WADError.modelNotFound
        }
        
        let convertData = await generateCombinedTexturePages(pagesPerRow: 8)
        
        var buffers: [GLTFBuffer] = []
        var bufferViews: [GLTFBufferView] = []
        var accessors: [GLTFAccessor] = []
        var meshes: [GLTFMesh] = []
        var nodes: [GLTFNode] = []
        var skins: [GLTFSkin] = []
        
        
        var binaryData = Data()
        
        func serializeMesh(_ meshIndex: Int) async throws -> Int {
            // Mesh submeshes
            var primitives: [GLTFMeshPrimitive] = []
            
            let vertexBuffers = try await self.meshes[meshIndex].generateVertexBuffers(in: self, withRemappedTexturePages: convertData.remapInfo)
            for vertexBuffer in vertexBuffers {
                var reader = DataReader(vertexBuffer.vertexBuffer)
                let stride = vertexBuffer.lightingType.stride
                
                var attributes: [String: Int] = [:]
                
                // Vertices
                do {
                    var writer = DataWriter()
                    
                    var xArray: [Float] = []
                    var yArray: [Float] = []
                    var zArray: [Float] = []
                    
                    for i in 0 ..< vertexBuffer.numVertices {
                        reader.set(i * stride)
                        let x: Float = try reader.read()
                        let y: Float = try reader.read()
                        let z: Float = try reader.read()
                        
                        writer.write(x)
                        writer.write(y)
                        writer.write(z)
                        
                        xArray.append(x)
                        yArray.append(y)
                        zArray.append(z)
                    }
                    
                    attributes["POSITION"] = accessors.count
                    
                    accessors.append(.init(
                        bufferView: bufferViews.count,
                        byteOffset: 0,
                        componentType: .float,
                        count: vertexBuffer.numVertices /*/ 3*/,
                        type: .vec3,
                        max: [xArray.max() ?? 0, yArray.max() ?? 0, zArray.max() ?? 0],
                        min: [xArray.min() ?? 0, yArray.min() ?? 0, zArray.min() ?? 0]
                    ))
                    
                    bufferViews.append(.init(
                        buffer: 0,
                        byteOffset: binaryData.count,
                        byteLength: writer.data.count,
                        byteStride: 12,
                        target: .arrayBuffer
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
                        byteStride: 12,
                        target: .arrayBuffer
                    ))
                    
                    binaryData.append(writer.data)
                }
                
                primitives.append(.init(
                    attributes: attributes,
                    material: nil,
                    mode: .triangles
                ))
            }
            
            let gltfMeshIndex = meshes.count
            meshes.append(.init(
                primitives: primitives
            ))
            
            return gltfMeshIndex
        }
        
        var skeletonJointNodes: [Int] = []
        func serializeJoint(_ joint: WKJoint) async throws -> Int {
            var childNodes: [Int] = []
            
            for child in joint.joints {
                let childNode = try await serializeJoint(child)
                childNodes.append(childNode)
            }
            
            let gltfMeshIndex = try await serializeMesh(joint.mesh)
            nodes.append(.init(
                children: childNodes.isEmpty ? nil : childNodes,
                mesh: gltfMeshIndex,
                rotation: [0,0,0,1],
                scale: [1,1,1],
                translation: [joint.offset.x, -joint.offset.y, -joint.offset.z]
            ))
            
            // Return index of the last generated node
            let jointNode = nodes.count - 1
            skeletonJointNodes.append(jointNode)
            return jointNode
        }
        let skeletonRootNode = try await serializeJoint(rootJoint)
        
        // Skinning
        //attributes["JOINTS_0"] = accessors.count
        //attributes["WEIGHTS_0"] = accessors.count
        
        
        buffers.append(.init(
            byteLength: binaryData.count
        ))
        
        
        skins.append(.init(
            skeleton: skeletonRootNode,
            joints: skeletonJointNodes
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
        
        
        //skins.append(.ini)
        
        
        let asset = GLTFAsset(generator: "WAD Editor 1.0.0-alpha1", version: "2.0")
        let gltf = GLTF(accessors: accessors, animations: nil, asset: asset, buffers: buffers, bufferViews: bufferViews, meshes: meshes, nodes: nodes, skins: skins)
        let library = GLTFLibrary(gltf: gltf, binaryChunks: [binaryData])
        
        return try await library.exportToGLB()
    }
}
