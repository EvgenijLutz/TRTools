//
//  Scene.swift
//  WAD Editor
//
//  Created by Evgenij Lutz on 15.02.24.
//

import Foundation
import WADKit
import Lemur


protocol Component {
    func update(timeElapsed: TimeInterval)
}

struct TransformComponent: Component {
    var location: SIMD3<Float>
    var rotation: SIMD3<Float>
    //var scale: SIMD3<Float>
    
    func update(timeElapsed: TimeInterval) {
        //
    }
}

struct RenderableComponent: Component {
    let canvas: LMCanvas
    
    /// Global transform
    var transform: TransformComponent
    
    struct MeshInstance {
        let mesh: LMMesh
        /// Local transform
        let transform: TransformComponent
    }
    var meshInstances: [MeshInstance] = []
    
    
    init(canvas: LMCanvas, transform: TransformComponent) {
        self.canvas = canvas
        self.transform = transform
    }
    
    func update(timeElapsed: TimeInterval) {
        //
    }
}

struct Entity {
    var components: [Component]
}


class TheScene {
    let canvas = LMCanvas()
    
    let entities: [Entity] = []
    
    
    func update(timeElapsed: TimeInterval) {
        for entity in entities {
            for component in entity.components {
                component.update(timeElapsed: timeElapsed)
            }
        }
    }
}
