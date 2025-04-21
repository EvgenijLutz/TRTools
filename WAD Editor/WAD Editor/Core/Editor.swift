//
//  Editor.swift
//  WAD Editor
//
//  Created by Evgenij Lutz on 16.02.24.
//

import Foundation
import Metal
import WADKit
import Lemur
import simd
import QuartzCore
import Cashmere


struct GPUMesh {
    var meshes: [LMMesh] = []
    var shadedMeshes: [LMMesh] = []
    var weightedMeshes: [LMMesh] = []
}


struct JointInstance {
    let joint: WKJoint
    /// Usually equals to `joint.offset`, but sometimes may be overwritten
    var origin: WKVector
    var meshInstances: [LMMeshInstance]
    
    var children: [JointInstance] = []
}


@MainActor
class Editor {
    let inputManager = InputManager()
    let canvas = Lemur.Canvas()
    var timelineModel: TimelineEditorModel?
    
    
    private(set) var wad: WAD? = nil
    
    private(set) var texturePages: [MTLTexture] = []
    private(set) var meshConnections: [GPUMesh] = []
    
    var currentMeshIndex: Int? = nil {
        didSet {
            //
        }
    }
    
    private var _orbitXDirection: Float = -1
    private var _orbitYDirection: Float = -1
    
    
    public var currentAnimatinIndex: Int = -1
    public var currentAnimation: WKAnimation? = nil {
        didSet {
            animationStartTime = -1
        }
    }
    private var animationStartTime: TimeInterval = -1
    private var jointInstance: JointInstance? = nil
    private var skinJointInstance: JointInstance? = nil
    
    
    init() {
#if false
        Task {
            do {
                if let url = Bundle.main.url(forResource: "medieval_knight", withExtension: "gltf") {
                //if let url = Bundle.main.url(forResource: "gltf_test", withExtension: "gltf") {
                    let gltf = try await GLTF.from(url)
                    print(gltf.asset)
                }
            }
            catch {
                print(error)
            }
        }
#endif
    }
    
    
    func clear() {
        reset()
        wad = nil
        texturePages = []
        meshConnections = []
    }
    
    
    private func reset() {
        canvas.opaqueMeshes = []
        canvas.shadedMeshes = []
        canvas.weightedMeshes = []
        currentMeshIndex = nil
        currentAnimatinIndex = -1
        currentAnimation = nil
        jointInstance = nil
        skinJointInstance = nil
        timelineModel?.clear()
    }
    
    
    func connectTimeline(model: TimelineEditorModel) {
        timelineModel = model
        timelineModel?.clear()
    }
    
    
    func loadTestData() async {
        guard let url = Bundle.main.url(forResource: "tut1", withExtension: "WAD") else {
        //guard let url = Bundle.main.url(forResource: "1-Home", withExtension: "wad") else {
        //guard let url = Bundle.main.url(forResource: "1-tutorial", withExtension: "wad") else {
            return
        }
        
        await loadData(at: url)
    }
    
    
    func loadData(at url: URL) async {
        //try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        clear()
        
        guard let renderEngine else {
            return
        }
        
        do {
            let now = CACurrentMediaTime()
            let wad = try await WAD.fromFileURL(url: url)
            let elapsed = CACurrentMediaTime() - now
            print("Load WAD time taken: \(elapsed) seconds")
            print(wad)
            
            // Prepare textures
            let convertData = await wad.generateCombinedTexturePages(pagesPerRow: 8)
            var textures: [MTLTexture] = []
            for holder in convertData.textures {
                let texture = try await renderEngine.createTexture(from: .init(holder.contents), width: convertData.width, height: convertData.width)
                textures.append(texture)
            }
            
            
            // Texture pages
//            var pages: [MTLTexture] = []
//            for page in wad.texturePages {
//                let bgraTexture = await page.generateBGRA8Texture()
//                let texture = try await renderEngine.createTexture(from: bgraTexture, width: WKTexturePage.width, height: WKTexturePage.height)
//                pages.append(texture)
//            }
//            texturePages = pages
            
            
            // Prepare meshes
            
            func getMeshIndices(for joint: WKJoint?, skipRoot: Bool = false) -> [Int] {
                let index: [Int] = if let mesh = joint?.mesh { [mesh] } else { [] }
                let indices = joint?.joints.flatMap { getMeshIndices(for: $0) } ?? []
                
                if skipRoot {
                    return indices
                }
                
                return index + indices
            }
            
            let laraSkinModel = wad.models.first { $0.identifier == .LARA_SKIN }
            let laraSkinIndices = getMeshIndices(for: laraSkinModel?.rootJoint)
            
            let laraSkinJointsModel = wad.models.first { $0.identifier == .LARA_SKIN_JOINTS }
            let laraSkinJointsIndices = getMeshIndices(for: laraSkinJointsModel?.rootJoint, skipRoot: true)
            
            func getJointPath(for mesh: Int, in joint: WKJoint) -> [Int]? {
                for (childIndex, child) in joint.joints.enumerated() {
                    if child.mesh == mesh {
                        return [childIndex]
                    }
                    
                    if let path = getJointPath(for: mesh, in: child) {
                        return [childIndex] + path
                    }
                }
                
                return nil
            }
            
            func getJointInfo(for mesh: Int) -> JointConnection? {
                guard let laraSkinModel, let laraSkinJointsModel, let laraSkinRoot = laraSkinModel.rootJoint, let laraSkinJointsRoot = laraSkinJointsModel.rootJoint else {
                    return nil
                }
                
                // Check if it's one of Lara's skin joints
                guard laraSkinJointsIndices.contains(mesh) else {
                    return nil
                }
                
                // Get path to the joint
                guard let jointPath = getJointPath(for: mesh, in: laraSkinJointsRoot) else {
                    return nil
                }
                
                var mesh0 = laraSkinRoot.mesh
                var offset0 = laraSkinRoot.offset
                var mesh1 = laraSkinRoot.mesh
                var offset1 = laraSkinRoot.offset
                func calculateMeshIndices(_ joint: WKJoint, path: [Int]) {
                    mesh1 = joint.mesh
                    offset1 = joint.offset
                    guard let firstIndex = path.first else {
                        return
                    }
                    
                    mesh0 = joint.mesh
                    offset0 = joint.offset
                    
                    calculateMeshIndices(joint.joints[firstIndex], path: .init(path.dropFirst()))
                }
                calculateMeshIndices(laraSkinRoot, path: jointPath)
                
                guard mesh0 != mesh1, laraSkinIndices.contains(mesh0), laraSkinIndices.contains(mesh1) else {
                    return nil
                }
                
                return .init(mesh0: mesh0, offset0: offset0, mesh1: mesh1, offset1: offset1, jointType: .regular)
            }
            
            
            var gpuMeshes: [GPUMesh] = []
            for (meshIndex, wadMesh) in wad.meshes.enumerated() {
                var connection = GPUMesh()
                
                let jointInfo = getJointInfo(for: meshIndex)
                
                let vertexBuffers = try await wadMesh.generateVertexBuffers(in: wad, jointInfo: jointInfo, withRemappedTexturePages: convertData.remapInfo)
                for vertexBuffer in vertexBuffers {
                    let buffer = try await renderEngine.createBuffer(from: vertexBuffer.vertexBuffer)
                    let mesh = LMMesh(vertexBuffer: buffer, numVertices: vertexBuffer.numVertices, texture: textures[vertexBuffer.textureIndex])
                    
                    switch vertexBuffer.layoutType {
                    case .normals:
                        connection.meshes.append(mesh)
                        
                    case .shades:
                        connection.shadedMeshes.append(mesh)
                        
                    case .normalsWithWeights:
                        connection.weightedMeshes.append(mesh)
                    }
                }
                
                gpuMeshes.append(connection)
            }
            
            self.wad = wad
            meshConnections = gpuMeshes
            
#if DEBUG
            // Select lara
            if let modelIndex = wad.models.firstIndex(where: { $0.identifier == .LARA }) {
                let model = wad.models[modelIndex]
                showModel(modelIndex: modelIndex, animationIndex: model.animations.isEmpty ? nil : 0)
            }
#endif
            
#if DEBUG
            // Export gltf
            let glb = try await wad.exportGLTFModel(.LARA)
            let path = FileManager.default.temporaryDirectory.appending(component: "test.glb")
            try glb.write(to: path)
            print("File written at \(path)")
#endif
        }
        catch {
            print(error)
        }
    }
    
    
    private func incrementMeshIndex(_ value: Int) {
        guard let index = currentMeshIndex else {
            return
        }
        var currentIndex = index + value
        
        if currentIndex < 0 {
            currentIndex = meshConnections.count - 1
        }
        
        if currentIndex >= meshConnections.count {
            currentIndex = 0
        }
        
        currentMeshIndex = currentIndex
    }
    
}


extension Editor: GraphicsViewDelegate {
    func canvasRendererUpdate(frame: CGSize, timestamp: CFTimeInterval, presentationTimestamp: CFTimeInterval?) {
        // Process input
        let inputData = inputManager.fetch()
        if inputData.isKeyDown(13) {
            incrementMeshIndex(-1)
        }
        if inputData.isKeyDown(1) {
            incrementMeshIndex(1)
        }
        
        // Update camera
        canvas.camera.viewportWidth = Float(frame.width)
        canvas.camera.viewportHeight = Float(frame.height)
        
        if let drag = inputData.mouseDrag(.left) {
            canvas.camera.rotate(x: Float(drag.y) * 0.005 * _orbitXDirection, y: Float(drag.x) * 0.005 * _orbitYDirection)
        }
        
        if let drag = inputData.mouseDrag(.other) {
            canvas.camera.drag(relativeTo: .init(), by: .init(x: Float(drag.x), y: Float(drag.y)))
        }
        
        if let scroll = inputData.scroll() {
            canvas.camera.magnify(Float(scroll.y) * 0.01)
        }
        
        // Animate
        if let currentAnimation, !currentAnimation.keyframes.isEmpty {
            if animationStartTime < 0 {
                animationStartTime = timestamp
            }
            
            //let frameDuration: Float = pow(2, Float(currentAnimation.frameDuration - 1))
            let frameDuration = Float(currentAnimation.frameDuration)
            let animationDuration = Float(currentAnimation.keyframes.count) * frameDuration / 30
            var animationProgress = Float(abs(timestamp - animationStartTime)) / animationDuration
            
            var currentKey = Int(animationProgress * Float(currentAnimation.keyframes.count))
            if currentKey >= currentAnimation.keyframes.count {
                currentKey = 0
                animationStartTime = -1
                animationProgress = 0
            }
            
            displayAnimationKeyframe(animationProgress)
        }
        else {
            displayDefaultState(jointInstance)
            displayDefaultState(skinJointInstance)
        }
        
    }
    
    
    func displayAnimationKeyframe(_ progress: Float) {
        guard let currentAnimation, !currentAnimation.keyframes.isEmpty else {
            displayDefaultState(jointInstance)
            displayDefaultState(skinJointInstance)
            return
        }
        
        let keyframeTime = progress * Float(currentAnimation.keyframes.count)
        var keyframeIndex = Int(floor(keyframeTime))
        let transitionTime = modf(keyframeTime).1
        if keyframeIndex >= currentAnimation.keyframes.count {
            keyframeIndex = 0
        }
        
        let keyframe = currentAnimation.keyframes[keyframeIndex]
        let nextKeyframe: WKKeyframe = {
            guard keyframeIndex + 1 < currentAnimation.keyframes.count else {
                guard currentAnimation.nextAnimation == currentAnimatinIndex else {
                    return keyframe
                }
                return currentAnimation.keyframes[0]
            }
            return currentAnimation.keyframes[keyframeIndex + 1]
        }()
        
        
        // It just became shitcode
        var meshIndex: Int = 0
        func updateTransform(_ instance: JointInstance, transform: matrix_float4x4, skinned: Bool) {
            guard meshIndex < keyframe.rotations.count else {
                return
            }
            
            let q0 = keyframe.rotations[meshIndex].simdQuaternion
            let q1 = nextKeyframe.rotations[meshIndex].simdQuaternion
            let q = simd_slerp(q0, q1, transitionTime)
            
            //var offset = instance.joint.offset.simd
            var offset = instance.origin.simd
            offset.x = offset.x
            offset.y = -offset.y
            offset.z = -offset.z
            let previous = transform * .translation(offset)
            let currentTransform = previous * q.matrix
            
            for meshInstance in instance.meshInstances {
                if skinned {
#if false
                    meshInstance.transform = previous * 0.5 + currentTransform * 0.5
#else
                    meshInstance.transform = previous
                    meshInstance.transform1 = currentTransform
#endif
                }
                else {
                    meshInstance.transform = currentTransform
                    meshInstance.transform1 = currentTransform
                }
            }
            
            for child in instance.children {
                meshIndex += 1
                updateTransform(child, transform: currentTransform, skinned: skinned)
            }
        }
        
        var offset0 = keyframe.offset.simd
        offset0.x = offset0.x
        offset0.y = -offset0.y
        offset0.z = -offset0.z
        
        var offset1 = nextKeyframe.offset.simd
        offset1.x = offset1.x
        offset1.y = -offset1.y
        offset1.z = -offset1.z
        
        let offset = offset1 * transitionTime + offset0 * (1 - transitionTime)
        if let jointInstance {
            updateTransform(jointInstance, transform: matrix_identity_float4x4 * .translation(offset), skinned: false)
        }
        
        if let skinJointInstance {
            meshIndex = 0
            let currentTransform = matrix_identity_float4x4 * .translation(offset)
            updateTransform(skinJointInstance, transform: currentTransform, skinned: true)
        }
    }
    
    
    func displayDefaultState(_ instance: JointInstance?) {
        guard let instance else {
            return
        }
        
        func updateTransform(_ instance: JointInstance, transform: matrix_float4x4) {
            //var offset = instance.joint.offset.simd
            var offset = instance.origin.simd
            offset.x = offset.x
            offset.y = -offset.y
            offset.z = -offset.z
            let currentTransform = transform * .translation(offset)
            
            for meshInstance in instance.meshInstances {
                meshInstance.transform = currentTransform
                meshInstance.transform1 = currentTransform
            }
            
            for child in instance.children {
                updateTransform(child, transform: currentTransform)
            }
        }
        
        updateTransform(instance, transform: matrix_identity_float4x4)
    }
}


extension Editor {
    private func editAnimations(for model: WKModel) {
        timelineModel?.clear()
        
        guard currentAnimatinIndex >= 0 else {
            return
        }
        
        guard let rootJoint = model.rootJoint else {
            return
        }
        
        let animation = model.animations[currentAnimatinIndex]
        
        
        var index = 0
        func spawnChildren(for parent: WKJoint, in collection: TMCollection) {
            let rotation = collection.createGroup("Rotation")
            
            func convert(_ points: [Float]) -> [Float] {
                func correct(_ value: Float) -> Float {
                    let v = value * 2
                    if v <= 1 {
                        return v
                    }
                    
                    return -(1 - (v - 1))
                }
                let points = points.map { correct($0) }
                
                func shortestDistance(from: Float, to: Float) -> Float {
                    // TODO: Correct negative offsets
//                    if sign(from) != sign(to) {
//                        if from < 0 {
//
//                        }
//                    }
//                    
//                    if abs(to - from) < 1 {
//                        return to - from
//                    }
//                    
//                    return -to + from
                    
                    return [
                        to - from,
                        to + 2 - from,
                        -(from + 2 - to)
                    ].min(by: { abs($0) < abs($1) }) ?? 0
                }
                
                var previousValue: Float = points.first ?? 0
                var previousDistance: Float = shortestDistance(from: 0, to: previousValue)
                var modifiedPoints: [Float] = [previousDistance]
                for value in points.dropFirst() {
                    let distance = shortestDistance(from: previousValue, to: value)
                    modifiedPoints.append(previousDistance + distance)
                    previousValue = value
                    previousDistance = distance
                }
                
#if false
                return modifiedPoints
#else
                // We need more drama
                let minValue = abs(modifiedPoints.min() ?? 0)
                let maxValue = abs(modifiedPoints.max() ?? 0)
                
                let range = max(minValue, maxValue)
                if range < 0.00001 {
                    return modifiedPoints
                }
                let multiplier = 0.9 / range
                
                return modifiedPoints.map {
                    $0 * multiplier
                }
#endif
            }
            
            let xPoints = convert(animation.keyframes.map({ $0.rotations[index].x }))
            let yPoints = convert(animation.keyframes.map({ $0.rotations[index].y }))
            let zPoints = convert(animation.keyframes.map({ $0.rotations[index].z }))
            
            _ = rotation.createAxis("x", records: xPoints.enumerated().map({ .init(x: Float($0), y: $1)}))
            _ = rotation.createAxis("y", records: yPoints.enumerated().map({ .init(x: Float($0), y: $1)}))
            _ = rotation.createAxis("z", records: zPoints.enumerated().map({ .init(x: Float($0), y: $1)}))
            
            
            //_ = rotation.createAxis("x", records: animation.keyframes.enumerated().map({ .init(x: Float($0), y: $1.rotations[index].x)}))
            //_ = rotation.createAxis("y", records: animation.keyframes.enumerated().map({ .init(x: Float($0), y: $1.rotations[index].y)}))
            //_ = rotation.createAxis("z", records: animation.keyframes.enumerated().map({ .init(x: Float($0), y: $1.rotations[index].z)}))
            
            index += 1
            
            for child in parent.joints {
                let currentOwner = collection.createCollection("some")
                spawnChildren(for: child, in: currentOwner)
            }
        }
        
        if let root = timelineModel?.createCollection("Root") {
            spawnChildren(for: rootJoint, in: root)
            root.resetControlPoints()
            root.updateLayout()
            //_ = timelineModel.updateLayout(animated: false)
        }
    }
}


extension Editor {
    private func findModel(_ modelIdentifier: TR4ObjectType) -> WKModel? {
        wad?.findModel(modelIdentifier)
    }
    
    func findMeshInfo(_ meshIndex: Int) -> (opaque: [LMMesh], shaded: [LMMesh], weighted: [LMMesh]) {
        let connection = meshConnections[meshIndex]
        return (connection.meshes, connection.shadedMeshes, connection.weightedMeshes)
    }
    
    private func spawnMovable(_ model: WKModel, meshRemapInfo: [Int] = [], remapOffsets: [WKVector?] = []) {
        guard let rootJoint = model.rootJoint else {
            return
        }
        
        var jointIndex = 0
        func addMesh(_ joint: WKJoint, origin: WKVector, visible: Bool = true) -> JointInstance {
            var instance = JointInstance(joint: joint, origin: origin, meshInstances: [])
            
            let meshIndex: Int = {
                guard !meshRemapInfo.isEmpty else {
                    return joint.mesh
                }
                
                guard jointIndex < meshRemapInfo.count else {
                    return joint.mesh
                }
                
                let remapIndex = meshRemapInfo[jointIndex]
                guard remapIndex >= 0 else {
                    return joint.mesh
                }
                
                return remapIndex
            }()
            
            let meshOffset: WKVector = {
                guard !remapOffsets.isEmpty else {
                    return joint.offset
                }
                
                guard jointIndex < remapOffsets.count else {
                    return joint.offset
                }
                
                return remapOffsets[jointIndex] ?? joint.offset
            }()
            instance.origin = meshOffset
            
            let info = findMeshInfo(meshIndex)
            if visible {
                let opaqueInstances = info.opaque.map { LMMeshInstance(mesh: $0) }
                canvas.opaqueMeshes.append(contentsOf: opaqueInstances)
                
                let shadedInstances = info.shaded.map { LMMeshInstance(mesh: $0) }
                canvas.shadedMeshes.append(contentsOf: shadedInstances)
                
                let weightedInstances = info.weighted.map { LMMeshInstance(mesh: $0) }
                canvas.weightedMeshes.append(contentsOf: weightedInstances)
                
                instance.meshInstances = opaqueInstances + shadedInstances + weightedInstances
            }
            else {
                instance.meshInstances = []
            }
            
            jointIndex += 1
            
            for joint in joint.joints {
                let child = addMesh(joint, origin: joint.offset)
                instance.children.append(child)
            }
            
            return instance
        }
        
        
        if model.identifier == .LARA_SKIN_JOINTS {
            skinJointInstance = addMesh(rootJoint, origin: .init(), visible: false)
        }
        else {
            jointInstance = addMesh(rootJoint, origin: .init())
        }
    }
    
    
    func showModel(modelIndex: Int, animationIndex: Int? = nil) {
        reset()
        
        guard let wad else {
            return
        }
        
        let model = wad.models[modelIndex]
        
        
        func unwrapMeshIndices(for joint: WKJoint?) -> [Int] {
            guard let joint else {
                return []
            }
            
            return [joint.mesh] + joint.joints.flatMap({ unwrapMeshIndices(for: $0) })
        }
        
        func unwrapMeshOffsets(for joint: WKJoint?) -> [WKVector] {
            guard let joint else {
                return []
            }
            
            return [joint.offset] + joint.joints.flatMap({ unwrapMeshOffsets(for: $0) })
        }
        
        
        // Replace LARA dummy model with skin and skin joints
        if model.identifier == .LARA, let laraSkinModel = findModel(.LARA_SKIN) {
            spawnMovable(laraSkinModel)
            
            if let laraSkinJointsModel = findModel(.LARA_SKIN_JOINTS) {
                spawnMovable(laraSkinJointsModel)
            }
        }
        else if model.identifier == .PISTOLS_ANIM, let laraSkinModel = findModel(.LARA_SKIN) {
            // 0 - left hip
            // 1 - right hip
            // 2 - left hand pistol
            // 3 - right hand pistol
            
            let originalIndices = unwrapMeshIndices(for: model.rootJoint)
            var remapInfo = unwrapMeshIndices(for: laraSkinModel.rootJoint)
            remapInfo[10] = originalIndices[1]
            remapInfo[13] = originalIndices[2]
            let offsets = unwrapMeshOffsets(for: laraSkinModel.rootJoint)
            spawnMovable(model, meshRemapInfo: remapInfo, remapOffsets: offsets)
            
            if let laraSkinJointsModel = findModel(.LARA_SKIN_JOINTS) {
                spawnMovable(laraSkinJointsModel)
            }
        }
        else if model.identifier == .UZI_ANIM, let laraSkinModel = findModel(.LARA_SKIN) {
            // 0 - left hip
            // 1 - right hip
            // 2 - left hand pistol
            // 3 - right hand pistol
            
            let originalIndices = unwrapMeshIndices(for: model.rootJoint)
            var remapInfo = unwrapMeshIndices(for: laraSkinModel.rootJoint)
            remapInfo[10] = originalIndices[3]
            remapInfo[13] = originalIndices[4]
            let offsets = unwrapMeshOffsets(for: laraSkinModel.rootJoint)
            spawnMovable(model, meshRemapInfo: remapInfo, remapOffsets: offsets)
            
            if let laraSkinJointsModel = findModel(.LARA_SKIN_JOINTS) {
                spawnMovable(laraSkinJointsModel)
            }
        }
        else if model.identifier == .SHOTGUN_ANIM, let laraSkinModel = findModel(.LARA_SKIN) {
            // 0 - left hip
            // 1 - right hip
            // 2 - left hand pistol
            // 3 - right hand pistol
            
            let originalIndices = unwrapMeshIndices(for: model.rootJoint)
            var remapInfo = unwrapMeshIndices(for: laraSkinModel.rootJoint)
            remapInfo[10] = originalIndices[5]
            //remapInfo[13] = originalIndices[4]
            let offsets = unwrapMeshOffsets(for: laraSkinModel.rootJoint)
            spawnMovable(model, meshRemapInfo: remapInfo, remapOffsets: offsets)
            
            if let laraSkinJointsModel = findModel(.LARA_SKIN_JOINTS) {
                spawnMovable(laraSkinJointsModel)
            }
        }
        else {
            spawnMovable(model)
        }
        
        
        if let animationIndex {
            let animation = model.animations[animationIndex]
            self.currentAnimatinIndex = animationIndex
            self.currentAnimation = animation
            
            animationStartTime = -1
            displayAnimationKeyframe(0)
            
            editAnimations(for: model)
        }
        else {
            displayDefaultState(jointInstance)
            displayDefaultState(skinJointInstance)
        }
    }
}
