//
//  Extensions.swift
//  WAD Editor
//
//  Created by Evgenij Lutz on 28.02.25.
//

import WADKit


public extension WKRotation {
    var quaternion: MTQuaternion {
        let mul: Float = .pi * 2
        let vector: MTVector3 = MTVector3(x, y, z) * mul
        let qx = MTQuaternion.fromEuler(.init(vector.x, 0, 0))
        let qy = MTQuaternion.fromEuler(.init(0, -vector.y, 0))
        let qz = MTQuaternion.fromEuler(.init(0, 0, -vector.z))
        return (qy * (qx * qz))
    }
}
