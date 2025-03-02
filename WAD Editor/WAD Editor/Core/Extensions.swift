//
//  Extensions.swift
//  WAD Editor
//
//  Created by Evgenij Lutz on 28.02.25.
//

import WADKit
import Lemur
import simd


extension WKVector {
    var simd: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}


extension WKRotation {
    var simdQuaternion: simd_quatf {
        let mul: Float = .pi * 2
        let vector = SIMD3<Float>(x, y, z) * mul
        let qx = Transform.quaternionFromEuler(.init(vector.x, 0, 0))
        let qy = Transform.quaternionFromEuler(.init(0, -vector.y, 0))
        let qz = Transform.quaternionFromEuler(.init(0, 0, -vector.z))        
        return (qy * (qx * qz))
    }
}


extension WKQuaternion {
    var simd: simd_quatf {
        .init(ix: ix, iy: iy, iz: iz, r: r)
    }
}
