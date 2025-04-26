//
//  WAD IO.swift
//  WAD Editor
//
//  Created by Evgenij Lutz on 15.03.25.
//

import Foundation
import WADKit


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
    case indexOutOfBounds(_ indx: Int)
}


extension WAD {
    public func exportGLTFModel(_ modelIndex: Int) async throws -> Data {
        guard modelIndex >= 0 && modelIndex < models.count else {
            throw WADExportError.indexOutOfBounds(modelIndex)
        }
        
        let model = models[modelIndex]
        return try await exportGLTFModel(model.identifier)
    }
    
    /// Generates a `glb` file contents that conform to [glTF Validator](https://github.khronos.org/glTF-Validator/) rules.
    public func exportGLTFModel(_ modelTyle: TR4ObjectType) async throws -> Data {
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
        
        let skinJointsModel: WKModel? = {
            if modelTyle == .LARA {
                guard let skinJointsModel = findModel(.LARA_SKIN_JOINTS) else {
                    return nil
                }
                return skinJointsModel
            }
        
            return nil
        }()
        
        guard let rootJoint = model.rootJoint else {
            throw WADError.modelNotFound
        }
        
        let pagesPerRow = Int(ceil(sqrt(Float(texturePages.count))))
        let convertData = await generateCombinedTexturePages(pagesPerRow: pagesPerRow)
        
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
                    doubleSided: false
                )
            )
        }
        
        
        // Model mesh
        class MeshSlice {
            // Collect vertex info for calculating min and max - for json validation purposes
            var xArray: [Float] = []
            var yArray: [Float] = []
            var zArray: [Float] = []
            var numVertices: Int = 0
            var vertexWriter = DataWriter()
            
            var normalWriter = DataWriter()
            var uvWriter = DataWriter()
            var jointWriter = DataWriter()
            var weightWriter = DataWriter()
            
            let textureIndex: Int
            let opaque: Bool
            let doubleSided: Bool
            let layoutType: WKVertexBuffer.LayoutType
            
            init(textureIndex: Int, opaque: Bool, doubleSided: Bool, layoutType: WKVertexBuffer.LayoutType) {
                self.textureIndex = textureIndex
                self.opaque = opaque
                self.doubleSided = doubleSided
                self.layoutType = layoutType
            }
        }
        var meshSlices: [MeshSlice] = []
        func findMeshSlice(for vertexBuffer: WKVertexBuffer) -> MeshSlice {
            for meshSlice in meshSlices {
                if meshSlice.textureIndex == vertexBuffer.textureIndex &&
                    meshSlice.opaque == vertexBuffer.opaque &&
                    meshSlice.doubleSided == vertexBuffer.doubleSided &&
                    meshSlice.layoutType == vertexBuffer.layoutType {
                    return meshSlice
                }
            }
            
            let slice = MeshSlice(textureIndex: vertexBuffer.textureIndex, opaque: vertexBuffer.opaque, doubleSided: vertexBuffer.doubleSided, layoutType: vertexBuffer.layoutType)
            meshSlices.append(slice)
            return slice
        }
        
        func serializeMesh(_ meshIndex: Int, withOffset offset: WKVector, forJointAt jointIndex: Int, withParentAt parentIndex: Int?, skinJointInfo: JointConnection?) async throws {
            let vertexBuffers = try await self.meshes[meshIndex].generateVertexBuffers(in: self, jointInfo: skinJointInfo, withRemappedTexturePages: convertData.remapInfo)
            for vertexBuffer in vertexBuffers {
                let slice = findMeshSlice(for: vertexBuffer)
                slice.numVertices += vertexBuffer.numVertices
                
                var reader = DataReader(vertexBuffer.vertexBuffer)
                let stride = vertexBuffer.layoutType.stride
                
                // Vertices
                for i in 0 ..< vertexBuffer.numVertices {
                    reader.set(i * stride)
                    var x: Float = try reader.read() + offset.x
                    var y: Float = try reader.read() - offset.y
                    var z: Float = try reader.read() - offset.z
                    
                    if vertexBuffer.layoutType == .normalsWithWeights {
                        reader.set(i * stride + 32)
                        x += try reader.read()
                        y += try reader.read()
                        z += try reader.read()
                    }
                    
                    slice.vertexWriter.write(x)
                    slice.vertexWriter.write(y)
                    slice.vertexWriter.write(z)
                    
                    slice.xArray.append(x)
                    slice.yArray.append(y)
                    slice.zArray.append(z)
                }
                
                // Normals
                if vertexBuffer.layoutType == .normals || vertexBuffer.layoutType == .normalsWithWeights {
                    for i in 0 ..< vertexBuffer.numVertices {
                        reader.set(i * stride + 20)
                        let x: Float = try reader.read()
                        let y: Float = try reader.read()
                        let z: Float = try reader.read()
                        
                        slice.normalWriter.write(x)
                        slice.normalWriter.write(y)
                        slice.normalWriter.write(z)
                    }
                }
                
                // UVs
                for i in 0 ..< vertexBuffer.numVertices {
                    reader.set(i * stride + 12)
                    let x: Float = try reader.read()
                    let y: Float = try reader.read()
                    
                    slice.uvWriter.write(x)
                    slice.uvWriter.write(y)
                }
                
                // Joints and weights
                for i in 0 ..< vertexBuffer.numVertices {
                    if vertexBuffer.layoutType == .normalsWithWeights, let parentIndex {
                        reader.set(i * stride + 44)
                        let w0: Float = try reader.read()
                        //let w1: Float = try reader.read()
                        if w0 > 0.01 {
                            slice.jointWriter.write(UInt16(parentIndex))
                        }
                        else {
                            slice.jointWriter.write(UInt16(jointIndex))
                        }
                    }
                    else {
                        slice.jointWriter.write(UInt16(jointIndex))
                    }
                    
                    slice.jointWriter.write(UInt16(0))
                    slice.jointWriter.write(UInt16(0))
                    slice.jointWriter.write(UInt16(0))
                    
                    slice.weightWriter.write(Float(1))
                    slice.weightWriter.write(Float(0))
                    slice.weightWriter.write(Float(0))
                    slice.weightWriter.write(Float(0))
                }
                
            }
        }
        
        /// Keyframe to node remap info
        var nodeRemapInfo: [Int] = []
        func node(for jointIndex: Int) -> Int {
            return nodeRemapInfo[jointIndex]
        }
        
        /// Data to build inverse matrices
        struct JointOffset {
            var offset: WKVector
        }
        var jointOffsets: [JointOffset] = []
        
        var skeletonJointNodes: [Int] = []
        
        var fparent = nodes.count
        
        struct NodeTree {
            var node: Int
            var children: [NodeTree] = []
        }
        var nodeCounter = 0
        func searchChildren(for joint: WKJoint) -> NodeTree {
            let children: [NodeTree] = joint.joints.reversed().map { searchChildren(for: $0) }
            
            let node = NodeTree(
                node: nodeCounter,
                children: children
            )
            nodeCounter += 1
            return node
        }
        
        let nodeTree: NodeTree = searchChildren(for: rootJoint)
        func parent(of childIndex: Int) -> Int {
            func look(in tree: NodeTree) -> Int? {
                for child in tree.children {
                    if child.node == childIndex {
                        return tree.node
                    }
                    
                    if let parentIndex = look(in: child) {
                        return parentIndex
                    }
                }
                
                return nil
            }
            
            return look(in: nodeTree) ?? childIndex
        }
        
        func serializeJoint(_ joint: WKJoint, parentJoint: WKJoint?, parentIndex: Int?, skinJoint: WKJoint?, name: String? = nil, globalOffset: WKVector = .init()) async throws -> Int {
            let currentJointIndex = fparent
            
            //let currentJointIndex = (parentIndex ?? -1) + 1
            let offset = globalOffset + joint.offset
            
            var childNodes: [Int] = []
            
            for (childIndex, child) in joint.joints.enumerated().reversed() {
                let childSkinJoint: WKJoint? = {
                    guard let skinJoint else {
                        return nil
                    }
                    
                    guard childIndex < skinJoint.joints.count else {
                        return nil
                    }
                    
                    return skinJoint.joints[childIndex]
                }()
                let childNode = try await serializeJoint(child, parentJoint: joint, parentIndex: currentJointIndex, skinJoint: childSkinJoint, globalOffset: offset)
                childNodes.append(childNode)
            }
            fparent += 1
            
            let jointNodeIndex = nodes.count
            try await serializeMesh(joint.mesh, withOffset: offset, forJointAt: jointNodeIndex, withParentAt: nil, skinJointInfo: nil)
            nodes.append(.init(
                children: childNodes.isEmpty ? nil : childNodes,
                rotation: [0,0,0,1],
                scale: [1,1,1],
                translation: [joint.offset.x, -joint.offset.y, -joint.offset.z],
                name: name
            ))
            
            // Write skin joint info
            if let parentJoint, let skinJoint {
                let jointInfo = JointConnection(
                    mesh0: parentJoint.mesh,
                    offset0: parentJoint.offset,
                    mesh1: joint.mesh,
                    offset1: joint.offset,
                    jointType: .regular
                )
                
                //try await serializeMesh(skinJoint.mesh, withOffset: offset, forJointAt: jointNodeIndex, withParentAt: parentIndex, skinJointInfo: jointInfo)
                try await serializeMesh(skinJoint.mesh, withOffset: offset, forJointAt: jointNodeIndex, withParentAt: parent(of: jointNodeIndex), skinJointInfo: jointInfo)
                //try await serializeMesh(skinJoint.mesh, withOffset: offset, forJointAt: nodeRemapInfo.count, withParentAt: nodeRemapInfo.count + 1, skinJointInfo: jointInfo)
            }
            
            // Return index of the last generated node
            skeletonJointNodes.append(jointNodeIndex)
            jointOffsets.append(.init(offset: offset))
            
            // Append node remap info
            nodeRemapInfo.insert(jointNodeIndex, at: 0)
            //nodeRemapInfo[currentJointIndex] = jointNodeIndex
            
            return jointNodeIndex
        }
        let skeletonRootNode = try await serializeJoint(rootJoint, parentJoint: nil, parentIndex: nil, skinJoint: skinJointsModel?.rootJoint, name: String(describing: modelTyle) + "-skeleton")
        
        
        // MARK: Write mesh data
        
        let modelMeshIndex = meshes.count
        do {
            // Mesh submeshes
            var primitives: [GLTFMeshPrimitive] = []
            
            for meshSlice in meshSlices {
                var attributes: [String: Int] = [:]
                
                // Vertices
                do {
                    attributes["POSITION"] = accessors.count
                    
                    accessors.append(.init(
                        bufferView: bufferViews.count,
                        byteOffset: 0,
                        componentType: .float,
                        count: meshSlice.numVertices /*/ 3*/,
                        type: .vec3,
                        max: [meshSlice.xArray.max() ?? 0, meshSlice.yArray.max() ?? 0, meshSlice.zArray.max() ?? 0],
                        min: [meshSlice.xArray.min() ?? 0, meshSlice.yArray.min() ?? 0, meshSlice.zArray.min() ?? 0]
                    ))
                    
                    bufferViews.append(.init(
                        buffer: 0,
                        byteOffset: binaryData.count,
                        byteLength: meshSlice.vertexWriter.data.count,
                        byteStride: 12,
                        target: .arrayBuffer
                    ))
                    
                    binaryData.append(meshSlice.vertexWriter.data)
                }
                
                // Normals
                if meshSlice.layoutType == .normals || meshSlice.layoutType == .normalsWithWeights {
                    attributes["NORMAL"] = accessors.count
                    
                    accessors.append(.init(
                        bufferView: bufferViews.count,
                        byteOffset: 0,
                        componentType: .float,
                        count: meshSlice.numVertices /*/ 3*/,
                        type: .vec3
                    ))
                    
                    bufferViews.append(.init(
                        buffer: 0,
                        byteOffset: binaryData.count,
                        byteLength: meshSlice.normalWriter.data.count,
                        byteStride: 12,
                        target: .arrayBuffer
                    ))
                    
                    binaryData.append(meshSlice.normalWriter.data)
                }
                
                // UVs
                do {
                    attributes["TEXCOORD_0"] = accessors.count
                    
                    accessors.append(.init(
                        bufferView: bufferViews.count,
                        byteOffset: 0,
                        componentType: .float,
                        count: meshSlice.numVertices /*/ 3*/,
                        type: .vec2
                    ))
                    
                    bufferViews.append(.init(
                        buffer: 0,
                        byteOffset: binaryData.count,
                        byteLength: meshSlice.uvWriter.data.count,
                        byteStride: 8,
                        target: .arrayBuffer
                    ))
                    
                    binaryData.append(meshSlice.uvWriter.data)
                }
                
                // Joints
                do {
                    attributes["JOINTS_0"] = accessors.count
                    
                    accessors.append(.init(
                        bufferView: bufferViews.count,
                        byteOffset: 0,
                        componentType: .unsignedShort,
                        count: meshSlice.numVertices /*/ 3*/,
                        type: .vec4
                    ))
                    
                    bufferViews.append(.init(
                        buffer: 0,
                        byteOffset: binaryData.count,
                        byteLength: meshSlice.jointWriter.data.count,
                        byteStride: 8,
                        target: .arrayBuffer
                    ))
                    
                    binaryData.append(meshSlice.jointWriter.data)
                }
                
                // Weights
                do {
                    attributes["WEIGHTS_0"] = accessors.count
                    
                    accessors.append(.init(
                        bufferView: bufferViews.count,
                        byteOffset: 0,
                        componentType: .float,
                        count: meshSlice.numVertices /*/ 3*/,
                        type: .vec4
                    ))
                    
                    bufferViews.append(.init(
                        buffer: 0,
                        byteOffset: binaryData.count,
                        byteLength: meshSlice.weightWriter.data.count,
                        byteStride: 16,
                        target: .arrayBuffer
                    ))
                    
                    binaryData.append(meshSlice.weightWriter.data)
                }
                
                primitives.append(.init(
                    attributes: attributes,
                    material: 0,
                    mode: .triangles
                ))
            }
            
            meshes.append(.init(
                primitives: primitives,
                name: String(describing: modelTyle) + "-mesh"
            ))
        }
        
        
        // MARK: Inverse bind matrices
        
        let inverseBindMatricesIndex = accessors.count
        do {
            var dataWriter = DataWriter()
            
            for jointOffset in jointOffsets {
                // Matrices are stored in the column-major order
                let inverseBindMatrix: [Float] = [
                    1, 0, 0, 0,
                    0, 1, 0, 0,
                    0, 0, 1, 0,
                    //jointOffset.offset.x, -jointOffset.offset.y, -jointOffset.offset.z, 1
                    -jointOffset.offset.x, jointOffset.offset.y, jointOffset.offset.z, 1
                    //0, 0, 0, 1
                ]
                
                for item in inverseBindMatrix {
                    dataWriter.write(item)
                }
            }
            
            accessors.append(.init(
                bufferView: bufferViews.count,
                byteOffset: 0,
                componentType: .float,
                count: jointOffsets.count,
                type: .mat4
            ))
            
            bufferViews.append(.init(
                buffer: 0,
                byteOffset: binaryData.count,
                byteLength: dataWriter.data.count,
                //byteStride: 64,
                //target: .arrayBuffer
            ))
            
            binaryData.append(dataWriter.data)
        }
        
        
        let skinIndex = skins.count
        skins.append(.init(
            inverseBindMatrices: inverseBindMatricesIndex,
            skeleton: skeletonRootNode,
            joints: skeletonJointNodes
        ))
        
        let rootNode = nodes.count
        nodes.append(
            .init(
                skin: skinIndex,
                mesh: modelMeshIndex
            )
        )
        
        scenes.append(
            .init(
                nodes: [rootNode, skeletonRootNode],
            )
        )
        
        
        // MARK: Animations
        
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
                            
                            let rotation = keyframe.rotations[jointIndex].quaternion
                            dataWriter.write(rotation.ix)
                            dataWriter.write(rotation.iy)
                            dataWriter.write(rotation.iz)
                            dataWriter.write(rotation.r)
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
                .init(
                    channels: channels,
                    samplers: samplers,
                    name: "Animation #\(animationIndex)"
                )
            )
        }
        
#if false
        // Export single animation
        exportAnimation(0)
#else
        // Export all animations
        for index in 0 ..< animationModel.animations.count {
            exportAnimation(index)
        }
#endif
        
        
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
