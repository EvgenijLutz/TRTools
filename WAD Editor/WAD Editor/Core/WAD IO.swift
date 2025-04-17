//
//  WAD IO.swift
//  WAD Editor
//
//  Created by Evgenij Lutz on 15.03.25.
//

import Foundation
import WADKit
import PNG


struct IOVector3 {
    var x: Float
    var y: Float
    var z: Float
    
    
    func length() -> Float {
        return sqrt(x*x + y*y + z*z)
    }
    
    func normalized() -> IOVector3 {
        let len = length()
        return .init(x: x / len, y: y / len, z: z / len)
    }
}


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


extension Collection {
    var orNothing: Self? {
        if self.isEmpty {
            return nil
        }
        
        return self
    }
}


enum WADExportError: Error {
    case corruptedImageData
}


extension WAD {
    /// Generates a `glb` file contents that conform to [glTF Validator](https://github.khronos.org/glTF-Validator/) rules.
    func exportGLTFAnimation(_ animationIndex: Int, of modelTyle: TR4ObjectType) async throws -> Data {
        guard let animationModel = findModel(modelTyle) else {
            throw WADError.modelNotFound
        }
        
        let model: WKModel = try {
            if modelTyle == .LARA {
                guard let skinModel = findModel(.LARA_SKIN) else {
                    throw WADError.modelNotFound
                }
                return skinModel
            }
            
            return animationModel
        }()
        
        guard let rootJoint = model.rootJoint else {
            throw WADError.modelNotFound
        }
        
        let convertData = await generateCombinedTexturePages(pagesPerRow: 8)
        
        var buffers: [GLTFBuffer] = []
        var bufferViews: [GLTFBufferView] = []
        var accessors: [GLTFAccessor] = []
        var images: [GLTFImage] = []
        var materials: [GLTFMaterial] = []
        var meshes: [GLTFMesh] = []
        var nodes: [GLTFNode] = []
        var samplers: [GLTFSampler] = []
        var scenes: [GLTFScene] = []
        var skins: [GLTFSkin] = []
        var textures: [GLTFTexture] = []
        
        
        // The skins array is not used at the moment. Do something useless here so that the compiler doesnt complain.
        skins.removeAll()
        
        
        var binaryData = Data()
        func appendBinaryData(_ data: Data, alignment: Int = 4) {
            binaryData.append(data)
            let result = binaryData.count % alignment
            if result > 0 {
                binaryData.append(contentsOf: Data(repeating: 0, count: alignment - result))
            }
        }
        
        
        // Write images, materials and image data - every albedo texture is a material
        for texture in convertData.textures {
            let pngData = try exportPNG(texture.contents, width: convertData.width, height: convertData.height)
            
            // Add image data
            let bufferOffset = binaryData.count
            //binaryData.append(contentsOf: pngData)
            appendBinaryData(pngData)
            
            let bufferViewIndx = bufferViews.count
            bufferViews.append(
                .init(
                    buffer: 0,
                    byteOffset: bufferOffset,
                    byteLength: pngData.count
                )
            )
            
            let imageIndex = images.count
            images.append(
                .init(
                    mimeType: "image/png",
                    bufferView: bufferViewIndx
                )
            )
            
            let samplerIndex = samplers.count
            samplers.append(
                .init(
                    magFilter: .nearest,
                    minFilter: .nearest,
                    wrapS: .clampToEdge,
                    wrapT: .clampToEdge
                )
            )
            
            let albedoTextureIndex = textures.count
            textures.append(
                .init(
                    sampler: samplerIndex,
                    source: imageIndex,
                )
            )
            
            materials.append(
                .init(
                    pbrMetallicRoughness: .init(
                        baseColorTexture: .init(
                            index: albedoTextureIndex,
                            texCoord: 0
                        ),
                        metallicFactor: 0.2,
                        roughnessFactor: 0.8
                    ),
                    alphaMode: .mask,
                    alphaCutoff: 0.5,
                    doubleSided: true
                )
            )
        }
        
        
        func serializeMesh(_ meshIndex: Int) async throws -> Int {
            // Mesh submeshes
            var primitives: [GLTFMeshPrimitive] = []
            
            let vertexBuffers = try await self.meshes[meshIndex].generateVertexBuffers(in: self, withRemappedTexturePages: convertData.remapInfo)
            for vertexBuffer in vertexBuffers {
                var reader = DataReader(vertexBuffer.vertexBuffer)
                let stride = vertexBuffer.layoutType.stride
                
                var attributes: [String: Int] = [:]
                
                // Vertices
                do {
                    var writer = DataWriter()
                    
                    // Collect vertex info for calculating min and max - for json validation purposes
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
                if vertexBuffer.layoutType == .normals || vertexBuffer.layoutType == .normalsWithWeights {
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
                
                // UVs
                do {
                    var writer = DataWriter()
                    
                    for i in 0 ..< vertexBuffer.numVertices {
                        reader.set(i * stride + 12)
                        let x: Float = try reader.read()
                        let y: Float = try reader.read()
                        
                        writer.write(x)
                        writer.write(y)
                    }
                    
                    attributes["TEXCOORD_0"] = accessors.count
                    
                    accessors.append(.init(
                        bufferView: bufferViews.count,
                        byteOffset: 0,
                        componentType: .float,
                        count: vertexBuffer.numVertices /*/ 3*/,
                        type: .vec2
                    ))
                    
                    bufferViews.append(.init(
                        buffer: 0,
                        byteOffset: binaryData.count,
                        byteLength: writer.data.count,
                        byteStride: 8,
                        target: .arrayBuffer
                    ))
                    
                    binaryData.append(writer.data)
                }
                
                primitives.append(.init(
                    attributes: attributes,
                    material: 0,
                    mode: .triangles
                ))
            }
            
            let gltfMeshIndex = meshes.count
            meshes.append(.init(
                primitives: primitives
            ))
            
            return gltfMeshIndex
        }
        
        var nodeRemapInfo: [Int] = []
        func node(for jointIndex: Int) -> Int {
            return nodeRemapInfo[jointIndex]
        }
        
        var skeletonJointNodes: [Int] = []
        func serializeJoint(_ joint: WKJoint) async throws -> Int {
            var childNodes: [Int] = []
            
            for child in joint.joints.reversed() {
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
            
            // Append node remap info
            nodeRemapInfo.insert(jointNode, at: 0)
            
            return jointNode
        }
        let skeletonRootNode = try await serializeJoint(rootJoint)
        
        // Skinning
        //attributes["JOINTS_0"] = accessors.count
        //attributes["WEIGHTS_0"] = accessors.count
        
        
//        let skinIndex = skins.count
//        skins.append(.init(
//            skeleton: skeletonRootNode,
//            joints: skeletonJointNodes
//        ))
        
//        let rootNode = nodes.count
//        nodes.append(
//            .init(
//                //skin: skinIndex,
//                mesh: nodes[skeletonRootNode].mesh
//            )
//        )
        
        scenes.append(
            .init(
                nodes: [skeletonRootNode],
            )
        )
        
        
        var animations: [GLTFAnimation] = []
        func exportAnimation(_ animationIndex: Int) {
            /// Keyframe time scale. Relative to Blender's 24 fps
            let timeScale = Float(1) / Float(60) * 2
            //let timeScale = Float(1) / Float(30) * 2
            //let timeScale = Float(1) / Float(24) * 2
            var channels: [GLTFChannel] = []
            var samplers: [GLTFAnimationSampler] = []
            
            
            func makeAccessor(for data: Data, of dataType: GLTFAccessorType, numElements: Int, min: Float? = nil, max: Float? = nil) -> Int {
                let bufferIndex = bufferViews.count
                bufferViews.append(
                    .init(
                        buffer: 0,
                        byteOffset: binaryData.count,
                        byteLength: data.count
                    )
                )
                
                binaryData.append(data)
                
                let accessorIndex = accessors.count
                let maxRange: [Float]? = {
                    guard let max else {
                        return nil
                    }
                    return [max]
                }()
                let minRange: [Float]? = {
                    guard let min else {
                        return nil
                    }
                    return [min]
                }()
                accessors.append(
                    .init(
                        bufferView: bufferIndex,
                        componentType: .float,
                        count: numElements,
                        type: dataType,
                        max: maxRange,
                        min: minRange
                    )
                )
                
                return accessorIndex
            }
            
            func makeSampler(time: Data, values: Data, dataType: GLTFAccessorType, count: Int, animationTimeScale: Float) -> Int {
                let max: Float = max(Float(0), Float(count - 1))
                let timeAccessorIndex = makeAccessor(for: time, of: .scalar, numElements: count, min: 0, max: max * timeScale * animationTimeScale)
                let dataAccessorIndex = makeAccessor(for: values, of: dataType, numElements: count)
                
                let samplerIndex = samplers.count
                samplers.append(
                    .init(
                        input: timeAccessorIndex,
                        interpolation: .linear,
                        output: dataAccessorIndex
                    )
                )
                
                return samplerIndex
            }
            
            
            // Serialize translation and rotation keyframes
            do {
                let animation = animationModel.animations[animationIndex]
                let animationTimeScale = Float(animation.frameDuration)
                let keyframeCount = max(1, animation.keyframes.count)
                
                // Translation
                do {
                    var timeWriter = DataWriter()
                    var dataWriter = DataWriter()
                    
                    // GLTF requires that an animation should contain at least one keyframe
                    if animation.keyframes.isEmpty {
                        timeWriter.write(Float(0))
                        
                        dataWriter.write(Float(0))
                        dataWriter.write(Float(0))
                        dataWriter.write(Float(0))
                    }
                    else {
                        for (index, keyframe) in animation.keyframes.enumerated() {
                            let keyframeTime = Float(index) * timeScale
                            timeWriter.write(keyframeTime * animationTimeScale)
                            
                            dataWriter.write(keyframe.offset.x)
                            dataWriter.write(-keyframe.offset.y)
                            dataWriter.write(-keyframe.offset.z)
                        }
                    }
                    
                    
                    let sampler = makeSampler(time: timeWriter.data, values: dataWriter.data, dataType: .vec3, count: keyframeCount, animationTimeScale: animationTimeScale)
                    channels.append(
                        .init(
                            sampler: sampler,
                            target: .init(
                                // Root node
                                node: nodeRemapInfo[0],
                                path: .translation
                            )
                        )
                    )
                }
                
                // Rotation
                func serializeJointAnimation(_ jointIndex: Int) {
                    var timeWriter = DataWriter()
                    var dataWriter = DataWriter()
                    
                    // GLTF requires that an animation should contain at least one keyframe
                    if animation.keyframes.isEmpty {
                        timeWriter.write(Float(0))
                        
                        dataWriter.write(Float(0))
                        dataWriter.write(Float(0))
                        dataWriter.write(Float(0))
                        dataWriter.write(Float(1))
                    }
                    else {
                        for (index, keyframe) in animation.keyframes.enumerated() {
                            timeWriter.write(Float(index) * timeScale * animationTimeScale)
                            
                            let rotation = keyframe.rotations[jointIndex].simdQuaternion
                            dataWriter.write(rotation.vector.x)
                            dataWriter.write(rotation.vector.y)
                            dataWriter.write(rotation.vector.z)
                            dataWriter.write(rotation.vector.w)
                        }
                    }
                    
                    
                    let sampler = makeSampler(time: timeWriter.data, values: dataWriter.data, dataType: .vec4, count: keyframeCount, animationTimeScale: animationTimeScale)
                    channels.append(
                        .init(
                            sampler: sampler,
                            target: .init(
                                // Root node
                                node: nodeRemapInfo[jointIndex],
                                path: .rotation
                            )
                        )
                    )
                }
                
                for jointIndex in 0 ..< nodeRemapInfo.count {
                    serializeJointAnimation(jointIndex)
                }
            }
            
            
            animations.append(
                .init(channels: channels, samplers: samplers)
            )
        }
        
        // Export single animation
        //exportAnimation(animationIndex)
        
        // Export all animations
        for index in 0 ..< animationModel.animations.count {
            exportAnimation(index)
        }
        
        
        // Write buffers
        buffers.append(.init(
            byteLength: binaryData.count
        ))
        
        
        let asset = GLTFAsset(generator: "WAD Editor 1.0.0-alpha1", version: "2.0")
        let gltf = GLTF(
            accessors: accessors.orNothing,
            animations: animations.orNothing,
            asset: asset,
            buffers: buffers.orNothing,
            bufferViews: bufferViews.orNothing,
            images: images.orNothing,
            materials: materials.orNothing,
            meshes: meshes.orNothing,
            nodes: nodes.orNothing,
            samplers: samplers.orNothing,
            scene: scenes.isEmpty ? nil : 0,
            scenes: scenes.orNothing,
            skins: skins.orNothing,
            textures: textures.orNothing
        )
        let library = GLTFLibrary(gltf: gltf, binaryChunks: [binaryData])
        
        return try await library.exportToGLB()
    }
}
