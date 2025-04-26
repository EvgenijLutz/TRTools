//
//  GLTF.swift
//  WAD Editor
//
//  Created by Evgenij Lutz on 09.03.25.
//

import Foundation


// MARK: Utilities

enum GLTFError: Error {
    case notSupported
    case notImplemented
    
    case other(_ message: String)
}


// MARK: Extension

/// JSON object with extension-specific objects.
///
/// Additional properties are allowed.
struct GLTFExtension: Sendable, Codable {
    var foo: String?
    
    init(from decoder: any Decoder) throws {
        //
    }
    
    enum CodingKeys: CodingKey {
        case foo
    }
    
    func encode(to encoder: any Encoder) throws {
        //var container = encoder.container(keyedBy: CodingKeys.self)
        //try container.encodeIfPresent(self.foo, forKey: .foo)
    }
}


// MARK: Extra

/// Application-specific data.
///
/// Although `extras` **MAY** have any type, it is common for applications to store and access custom data as key/value pairs. Therefore, `extras` **SHOULD** be a JSON object rather than a primitive value for best portability.
struct GLTFExtra: Sendable, Codable {
    var foo: String?
}


// MARK: Accessors

enum GLTFComponentType: Int, Codable {
    case byte = 5120
    case unsignedByte = 5121
    case short = 5122
    case unsignedShort = 5123
    case unsignedInt = 5125
    case float = 5126
}


enum GLTFAccessorType: String, Codable {
    case scalar = "SCALAR"
    case vec2 = "VEC2"
    case vec3 = "VEC3"
    case vec4 = "VEC4"
    case mat2 = "MAT2"
    case mat3 = "MAT3"
    case mat4 = "MAT4"
}


enum GLTFAccessorSparseIndexComponentType: Int, Codable {
    case unsignedByte = 5121
    case unsignedShort = 5123
    case unsignedInt = 5125
}


/// An object pointing to a buffer view containing the indices of deviating accessor values. The number of indices is equal to `accessor.sparse.count`. Indices **MUST** strictly increase.
struct GLTFAccessorSparseIndices: Sendable, Codable {
    /// The index of the buffer view with sparse indices.
    ///
    /// The referenced buffer view **MUST NOT** have its `target` or `byteStride` properties defined. The buffer view and the optional `byteOffset` **MUST** be aligned to the `componentType` byte length.
    var bufferView: Int
    
    
    /// The offset relative to the start of the buffer view in bytes.
    var byteOffset: Int?
    
    
    /// The indices data type.
    var componentType: GLTFAccessorSparseIndexComponentType
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


/// An object pointing to a buffer view containing the deviating accessor values.
///
/// The number of elements is equal to `accessor.sparse.count` times number of components. The elements have the same component type as the base accessor. The elements are tightly packed. Data **MUST** be aligned following the same rules as the base accessor.
struct GLTFAccessorSparseValues: Sendable, Codable {
    /// The index of the bufferView with sparse values.
    ///
    /// The referenced buffer view **MUST NOT** have its `target` or `byteStride` properties defined.
    var bufferView: Int
    
    
    /// The offset relative to the start of the buffer view in bytes.
    var byteOffset: Int?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


/// Sparse storage of accessor values that deviate from their initialization value.
struct GLTFAccessorSparse: Sendable, Codable {
    /// Number of deviating accessor values stored in the sparse array.
    var count: Int
    
    
    /// An object pointing to a buffer view containing the indices of deviating accessor values. The number of indices is equal to `count`. Indices **MUST** strictly increase.
    var indices: GLTFAccessorSparseIndices
    
    
    /// An object pointing to a buffer view containing the deviating accessor values.
    var values: GLTFAccessorSparseValues
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


/// A typed view into a buffer view that contains raw binary data.
struct GLTFAccessor: Sendable, Codable {
    /// The index of the buffer view.
    ///
    /// When undefined, the accessor **MUST** be initialized with zeros; sparse property or extensions **MAY** override zeros with actual values.
    var bufferView: Int
    
    
    /// The offset relative to the start of the buffer view in bytes.
    ///
    /// This **MUST** be a multiple of the size of the component datatype. This property **MUST NOT** be defined when bufferView is undefined.
    var byteOffset: Int? // = 0
    
    
    /// The datatype of the accessor’s components.
    ///
    /// `unsignedInt` type **MUST NOT** be used for any accessor that is not referenced by `mesh.primitive.indices`.
    var componentType: GLTFComponentType
    
    
    /// Specifies whether integer data values are normalized (true) to `[0, 1] (for unsigned types)` or to `[-1, 1] (for signed types)` when they are accessed.
    ///
    /// This property **MUST NOT** be set to true for accessors with `float` or `unsignedInt` component type.
    var normalized: Bool? // = false
    
    
    /// The number of elements referenced by this accessor, not to be confused with the number of bytes or number of components.
    var count: Int
    
    
    /// Specifies if the accessor’s elements are scalars, vectors, or matrices.
    var type: GLTFAccessorType
    
    
    /// Maximum value of each component in this accessor.
    ///
    /// Array elements **MUST** be treated as having the same data type as accessor’s `componentType`. Both `min` and `max` arrays have the same length. The length is determined by the value of the type property; it can be 1, 2, 3, 4, 9, or 16.
    ///
    /// `normalized` property has no effect on array values: they always correspond to the actual values stored in the buffer. When the accessor is sparse, this property **MUST** contain maximum values of accessor data with sparse substitution applied.
    var max: [Float]?
    
    
    /// Minimum value of each component in this accessor.
    ///
    /// Array elements **MUST** be treated as having the same data type as accessor’s `componentType`. Both `min` and `max` arrays have the same length. The length is determined by the value of the type property; it can be 1, 2, 3, 4, 9, or 16.
    ///
    /// `normalized` property has no effect on array values: they always correspond to the actual values stored in the buffer. When the accessor is sparse, this property **MUST** contain minimum values of accessor data with sparse substitution applied.
    var min: [Float]?
    
    
    /// Sparse storage of elements that deviate from their initialization value.
    var sparse: GLTFAccessorSparse?
    
    
    /// The user-defined name of this object.
    ///
    /// This is not necessarily unique, e.g., an accessor and a buffer could have the same name, or two accessors could even have the same name.
    var name: String?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


// MARK: Animaitons

enum GLTFTargetPath: String, Codable {
    case translation = "translation"
    case rotation = "rotation"
    case scale = "scale"
    case weights = "weights"
}


/// Animation Channel Target
///
/// The descriptor of the animated property.
///
/// - Seealso: [Animation Channel Target](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-animation-channel-target)
struct GLTFChannelTarget: Sendable, Codable {
    /// The index of the node to animate.
    ///
    /// When undefined, the animated object **MAY** be defined by an extension.
    var node: Int?
    
    
    /// The name of the node’s TRS property to animate, or the `"weights"` of the Morph Targets it instantiates.
    ///
    /// For the `"translation"` property, the values that are provided by the sampler are the translation along the X, Y, and Z axes.
    ///
    /// For the `"rotation"` property, the values are a quaternion in the order (x, y, z, w), where w is the scalar.
    ///
    /// For the `"scale"` property, the values are the scaling factors along the X, Y, and Z axes.
    var path: GLTFTargetPath
}


/// Animation Channel
///
/// An animation channel combines an animation sampler with a target property being animated.
///
/// - Seealso: [Animation Channel](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-animation-channel)
struct GLTFChannel: Sendable, Codable {
    /// The index of a sampler in this animation used to compute the value for the target, e.g., a node’s translation, rotation, or scale (TRS).
    var sampler: Int
    
    
    /// The descriptor of the animated property.
    var target: GLTFChannelTarget
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


/// Interpolation algorithm.
enum GLTFInterpolation: String, Codable {
    /// The animated values remain constant to the output of the first keyframe, until the next keyframe. The number of output elements **MUST** equal the number of input elements.
    case step = "STEP"
    
    /// The animated values are linearly interpolated between keyframes. When targeting a rotation, spherical linear interpolation (slerp) **SHOULD** be used to interpolate quaternions. The number of output elements **MUST** equal the number of input elements.
    case linear = "LINEAR"
    
    /// The animation’s interpolation is computed using a cubic spline with specified tangents. The number of output elements **MUST** equal three times the number of input elements. For each input element, the output stores three elements, an in-tangent, a spline vertex, and an out-tangent. There **MUST** be at least two keyframes when using this interpolation.
    case cubicSpline = "CUBICSPLINE"
}


/// Animation Sampler
///
/// An animation sampler combines timestamps with a sequence of output values and defines an interpolation algorithm.
/// - Seealso: [Animation Sampler](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-animation-sampler)
struct GLTFAnimationSampler: Sendable, Codable {
    /// The index of an accessor containing keyframe timestamps.
    ///
    /// The accessor **MUST** be of scalar type with floating-point components. The values represent time in seconds `with time[0] >= 0.0`, and strictly increasing values, i.e., `time[n + 1] > time[n]`.
    var input: Int
    
    
    /// Interpolation algorithm.
    var interpolation: GLTFInterpolation? // = .linear
    
    
    /// The index of an accessor, containing keyframe output values.
    var output: Int
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


/// A keyframe animation.
///
/// - Seealso: [Animation](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-animation)
struct GLTFAnimation: Sendable, Codable {
    /// An array of animation channels.
    ///
    /// An animation channel combines an animation sampler with a target property being animated. Different channels of the same animation **MUST NOT** have the same targets.
    var channels: [GLTFChannel]
    
    
    /// An array of animation samplers.
    ///
    /// An animation sampler combines timestamps with a sequence of output values and defines an interpolation algorithm.
    var samplers: [GLTFAnimationSampler]
    
    
    /// The user-defined name of this object.
    ///
    /// This is not necessarily unique, e.g., an accessor and a buffer could have the same name, or two accessors could even have the same name.
    var name: String?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


// MARK: Asset

/// Metadata about the glTF asset.
struct GLTFAsset: Sendable, Codable {
    /// A copyright message suitable for display to credit the content creator.
    var copyright: String?
    
    
    /// Tool that generated this glTF model. Useful for debugging.
    var generator: String?
    
    
    /// The glTF version in the form of `<major>.<minor>` that this asset targets.
    var version: String
    
    
    /// The minimum glTF version in the form of `<major>.<minor>` that this asset targets. This property **MUST NOT** be greater than the asset version.
    var minVersion: String?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


// MARK: Buffers

/// Buffer
///
/// A buffer points to binary geometry, animation, or skins.
///
/// - Seealso: [Buffer](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-buffer)
struct GLTFBuffer: Sendable, Codable {
    /// The URI (or IRI) of the buffer. Relative paths are relative to the current glTF asset. Instead of referencing an external file, this field **MAY** contain a `data:-URI`.
    var uri: String?
    
    
    /// The length of the buffer in bytes.
    var byteLength: Int
    
    
    /// The user-defined name of this object. This is not necessarily unique, e.g., an accessor and a buffer could have the same name, or two accessors could even have the same name.
    var name: String?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


// MARK: Buffer views

/// The hint representing the intended GPU buffer type to use with this buffer view.
enum GLTFBufferViewTarget: Int, Codable {
    case arrayBuffer = 34962
    case elementArrayBuffer = 34963
}


/// Buffer View
///
/// A view into a buffer generally representing a subset of the buffer.
///
/// - Seealso: [Buffer View](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-bufferview)
struct GLTFBufferView: Sendable, Codable {
    /// The index of the buffer.
    var buffer: Int
    
    
    /// The offset into the buffer in bytes.
    var byteOffset: Int? // = 0
    
    
    /// The offset into the buffer in bytes.
    var byteLength: Int
    
    
    /// The stride, in bytes, between vertex attributes.
    ///
    /// When this is not defined, data is tightly packed. When two or more accessors use the same buffer view, this field **MUST** be defined.
    var byteStride: Int?
    
    
    /// The hint representing the intended GPU buffer type to use with this buffer view.
    var target: GLTFBufferViewTarget?
    
    
    /// The user-defined name of this object.
    ///
    /// This is not necessarily unique, e.g., an accessor and a buffer could have the same name, or two accessors could even have the same name.
    var name: String?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


// MARK: Cameras

enum GLTFCameraType: String, Codable {
    case perspective
    case orthographic
}


/// Camera Orthographic
///
/// An orthographic camera containing properties to create an orthographic projection matrix.
///
/// - Seealso: [Camera Orthographic](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-camera-orthographic)
struct GLTFOrthographicCamera: Sendable, Codable {
    /// The floating-point horizontal magnification of the view.
    ///
    /// This value **MUST NOT** be equal to zero. This value **SHOULD NOT** be negative.
    var xmag: Float
    
    
    /// The floating-point vertical magnification of the view.
    ///
    /// This value **MUST NOT** be equal to zero. This value **SHOULD NOT** be negative.
    var ymag: Float
    
    
    /// The floating-point distance to the far clipping plane.
    ///
    /// This value **MUST NOT** be equal to zero. zfar **MUST** be greater than znear.
    var zfar: Float
    
    
    /// The floating-point distance to the near clipping plane.
    var znear: Float
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


/// Camera Perspective
///
/// A perspective camera containing properties to create a perspective projection matrix.
///
/// - Seealso: [Camera Perspective](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-camera-perspective)
struct GLTFPerspectiveCamera: Sendable, Codable {
    /// The floating-point aspect ratio of the field of view.
    ///
    /// When undefined, the aspect ratio of the rendering viewport **MUST** be used.
    var aspectRatio: Float?
    
    
    /// The floating-point vertical field of view in radians.
    ///
    /// This value **SHOULD** be less than π.
    var yfov: Float
    
    
    /// The floating-point distance to the far clipping plane.
    ///
    /// When defined, zfar **MUST** be greater than znear. If zfar is undefined, client implementations **SHOULD** use infinite projection matrix.
    var zfar: Float
    
    
    /// The floating-point distance to the near clipping plane.
    var znear: Float
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


/// Camera
///
/// A camera’s projection. A node **MAY** reference a camera to apply a transform to place the camera in the scene.
///
/// - Seealso: [Camera](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-camera)
struct GLTFCamera: Sendable, Codable {
    /// An orthographic camera containing properties to create an orthographic projection matrix.
    ///
    /// This property **MUST NOT** be defined when perspective is defined.
    var orthographic: GLTFOrthographicCamera?
    
    
    /// A perspective camera containing properties to create a perspective projection matrix.
    ///
    /// This property **MUST NOT** be defined when orthographic is defined.
    var perspective: GLTFPerspectiveCamera?
    
    
    /// Specifies if the camera uses a perspective or orthographic projection.
    ///
    /// Based on this, either the camera’s perspective or orthographic property **MUST** be defined.
    var type: GLTFCameraType
    
    
    /// The user-defined name of this object.
    ///
    /// This is not necessarily unique, e.g., an accessor and a buffer could have the same name, or two accessors could even have the same name.
    var name: String?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


// MARK: Images

/// Image data used to create a texture.
///
/// Image **MAY** be referenced by an URI (or IRI) or a buffer view index.
struct GLTFImage: Sendable, Codable {
    /// The URI (or IRI) of the image.
    ///
    /// Relative paths are relative to the current glTF asset. Instead of referencing an external file, this field **MAY** contain a `data:-URI`. This field **MUST NOT** be defined when `bufferView` is defined.
    var uri: String?
    
    
    /// The image’s media type.
    ///
    /// This field **MUST** be defined when bufferView is defined.
    ///
    /// Allowed values:
    /// - `"image/jpeg"`
    /// - `"image/png"`
    var mimeType: String?
    
    
    /// The index of the bufferView that contains the image.
    ///
    /// This field **MUST NOT** be defined when uri is defined.
    var bufferView: Int?
    
    
    /// The user-defined name of this object.
    ///
    /// This is not necessarily unique, e.g., an accessor and a buffer could have the same name, or two accessors could even have the same name.
    var name: String?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


// MARK: Materials

/// Texture Info
///
/// Reference to a texture.
///
/// - Seealso: [Texture Info](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-textureinfo)
struct GLTFTextureInfo: Sendable, Codable {
    /// The index of the texture.
    var index: Int
    
    
    /// This integer value is used to construct a string in the format `TEXCOORD_<set index>` which is a reference to a key in `mesh.primitives.attributes` (e.g. a value of 0 corresponds to `TEXCOORD_0`). A mesh primitive **MUST** have the corresponding texture coordinate attributes for the material to be applicable to it.
    var texCoord: Int? // = 0
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


/// Material PBR Metallic Roughness
///
/// A set of parameter values that are used to define the metallic-roughness material model from Physically-Based Rendering (PBR) methodology.
///
/// - Seealso: [Material PBR Metallic Roughness](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-material-pbrmetallicroughness)
struct GLTFMaterialPBRMetallicRoughness: Sendable, Codable {
    /// The factors for the base color of the material.
    ///
    /// This value defines linear multipliers for the sampled texels of the base color texture.
    ///
    /// Each element in the array **MUST** be greater than or equal to 0 and less than or equal to 1.
    var baseColorFactor: [Float]? // = [1,1,1,1]
    
    
    /// The base color texture.
    ///
    /// The first three components (RGB) **MUST** be encoded with the sRGB transfer function. They specify the base color of the material. If the fourth component (A) is present, it represents the linear alpha coverage of the material. Otherwise, the alpha coverage is equal to 1.0. The `material.alphaMode` property specifies how alpha is interpreted. The stored texels **MUST NOT** be premultiplied. When undefined, the texture **MUST** be sampled as having 1.0 in all components.
    var baseColorTexture: GLTFTextureInfo?
    
    
    /// The factor for the metalness of the material.
    ///
    /// This value defines a linear multiplier for the sampled metalness values of the metallic-roughness texture.
    var metallicFactor: Float? // = 1
    
    
    /// The factor for the roughness of the material.
    ///
    /// This value defines a linear multiplier for the sampled roughness values of the metallic-roughness texture.
    var roughnessFactor: Float? // = 1
    
    
    /// The metallic-roughness texture.
    ///
    /// The metalness values are sampled from the B channel. The roughness values are sampled from the G channel. These values **MUST** be encoded with a linear transfer function. If other channels are present (R or A), they **MUST** be ignored for metallic-roughness calculations. When undefined, the texture **MUST** be sampled as having `1.0` in G and B components.
    var metallicRoughnessTexture: GLTFTextureInfo?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


/// Material Normal Texture Info
///
/// Reference to a texture.
///
/// - Seealso: [Material Normal Texture Info](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-material-normaltextureinfo)
struct GLTFNormalTextureInfo: Sendable, Codable {
    /// The index of the texture.
    var index: Int
    
    
    /// This integer value is used to construct a string in the format `TEXCOORD_<set index>` which is a reference to a key in `mesh.primitives.attributes` (e.g. a value of 0 corresponds to `TEXCOORD_0`). A mesh primitive **MUST** have the corresponding texture coordinate attributes for the material to be applicable to it.
    var texCoord: Int? // = 0
    
    
    /// The scalar parameter applied to each normal vector of the texture.
    ///
    /// This value scales the normal vector in X and Y directions using the formula: `scaledNormal = normalize<sampled normal texture value> * 2.0 - 1.0) * vec3(<normal scale>, <normal scale>, 1.0`.
    var scale: Int? // = 1
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


/// Material Occlusion Texture Info
///
/// Reference to a texture.
///
/// - Seealso: [Material Occlusion Texture Info](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-material-occlusiontextureinfo)
struct GLTFOcclusionTextureInfo: Sendable, Codable {
    /// The index of the texture.
    var index: Int
    
    
    /// This integer value is used to construct a string in the format `TEXCOORD_<set index>` which is a reference to a key in `mesh.primitives.attributes` (e.g. a value of 0 corresponds to `TEXCOORD_0`). A mesh primitive **MUST** have the corresponding texture coordinate attributes for the material to be applicable to it.
    var texCoord: Int? // = 0
    
    
    /// A scalar parameter controlling the amount of occlusion applied.
    ///
    /// A value of `0.0` means no occlusion. A value of `1.0` means full occlusion. This value affects the final occlusion value as: `1.0 + strength * (<sampled occlusion texture value> - 1.0)`.
    var strength: Int? // = 1
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


enum GLTFMaterialAlphaMode: String, Codable {
    /// The alpha value is ignored, and the rendered output is fully opaque.
    case opaque = "OPAQUE"
    
    
    /// The rendered output is either fully opaque or fully transparent depending on the alpha value and the specified alphaCutoff value; the exact appearance of the edges **MAY** be subject to implementation-specific techniques such as “Alpha-to-Coverage”.
    case mask = "MASK"
    
    
    /// The alpha value is used to composite the source and destination areas. The rendered output is combined with the background using the normal painting operation (i.e. the Porter and Duff over operator).
    case blend = "BLEND"
}


/// Material
///
/// The material appearance of a primitive.
///
/// - Seealso: [Material](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-material)
struct GLTFMaterial: Sendable, Codable {
    /// The user-defined name of this object.
    ///
    /// This is not necessarily unique, e.g., an accessor and a buffer could have the same name, or two accessors could even have the same name.
    var name: String?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
    
    
    /// A set of parameter values that are used to define the metallic-roughness material model from Physically Based Rendering (PBR) methodology.
    ///
    /// When undefined, all the default values of `pbrMetallicRoughness` **MUST** apply.
    var pbrMetallicRoughness: GLTFMaterialPBRMetallicRoughness?
    
    
    /// A set of parameter values that are used to define the metallic-roughness material model from Physically Based Rendering (PBR) methodology.
    ///
    /// When undefined, all the default values of pbrMetallicRoughness **MUST** apply.
    var normalTexture: GLTFNormalTextureInfo?
    
    
    /// The occlusion texture.
    ///
    /// The occlusion values are linearly sampled from the R channel. Higher values indicate areas that receive full indirect lighting and lower values indicate no indirect lighting. If other channels are present (GBA), they **MUST** be ignored for occlusion calculations. When undefined, the material does not have an occlusion texture.
    var occlusionTexture: GLTFOcclusionTextureInfo?
    
    
    /// The emissive texture.
    ///
    /// It controls the color and intensity of the light being emitted by the material. This texture contains RGB components encoded with the sRGB transfer function. If a fourth component (A) is present, it **MUST** be ignored. When undefined, the texture **MUST** be sampled as having 1.0 in RGB components.
    var emissiveTexture: GLTFTextureInfo?
    
    
    /// The factors for the emissive color of the material.
    ///
    /// This value defines linear multipliers for the sampled texels of the emissive texture. Each element in the array **MUST** be greater than or equal to 0 and less than or equal to 1.
    var emissiveFactor: [Float]? // = [0,0,0]
    
    
    /// The material’s alpha rendering mode enumeration specifying the interpretation of the alpha value of the base color.
    var alphaMode: GLTFMaterialAlphaMode? // = .opaque
    
    
    /// Specifies the cutoff threshold when in MASK alpha mode.
    ///
    /// If the alpha value is greater than or equal to this value then it is rendered as fully opaque, otherwise, it is rendered as fully transparent. A value greater than 1.0 will render the entire material as fully transparent. This value **MUST** be ignored for other alpha modes. When alphaMode is not defined, this value **MUST NOT** be defined.
    var alphaCutoff: Float? // = 0.5
    
    
    /// Specifies whether the material is double sided.
    ///
    /// When this value is false, back-face culling is enabled. When this value is true, back-face culling is disabled and double-sided lighting is enabled. The back-face **MUST** have its normals reversed before the lighting equation is evaluated.
    var doubleSided: Bool? // = false
}


// MARK: Meshes

enum GLTFMeshPrimitiveTopologyMode: Int, Codable {
    case points = 0
    case lines = 1
    case lineLoop = 2
    case lineStrip = 3
    case triangles = 4
    case triangleStrip = 5
    case triangleFan = 6
}

/// Mesh Primitive
///
/// - Seealso: [Mesh Primitive](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-mesh-primitive)
struct GLTFMeshPrimitive: Sendable, Codable {
    //struct GLTFAttributes: Sendable, Codable {
    //    // TODO : This should be a plain json object. Anything below a result of observation of some gltf files
    //    var JOINTS_0: Int?
    //    var NORMAL: Int?
    //    var POSITION: Int?
    //    var TANGENT: Int?
    //    var TEXCOORD_0: Int?
    //    var WEIGHTS_0: Int?
    //}
    //var attributes: GLTFAttributes?
    
    
    /// A plain JSON object, where each key corresponds to a mesh attribute semantic and each value is the index of the accessor containing attribute’s data.
    var attributes: [String : Int]
    
    
    /// The index of the accessor that contains the vertex indices.
    ///
    /// When this is undefined, the primitive defines non-indexed geometry. When defined, the accessor **MUST** have SCALAR type and an unsigned integer component type.
    var indices: Int?
    
    
    /// The index of the material to apply to this primitive when rendering.
    var material: Int?
    
    
    /// The topology type of primitives to render.
    var mode: GLTFMeshPrimitiveTopologyMode? // = .triangles
    
    
    // TODO: Check if it's okay to use dictionary as a json object just like attributes
    // /// An array of morph targets.
    // var targets: [String : Int]?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}

/// Mesh
///
/// A set of primitives to be rendered. Its global transform is defined by a node that references it.
///
/// - Seealso: [Mesh](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-mesh)
struct GLTFMesh: Sendable, Codable {
    /// An array of primitives, each defining geometry to be rendered.
    var primitives: [GLTFMeshPrimitive]
    
    
    /// Array of weights to be applied to the morph targets.
    ///
    /// The number of array elements **MUST** match the number of morph targets.
    var weights: [Float]?
    
    
    /// The user-defined name of this object.
    ///
    /// This is not necessarily unique, e.g., an accessor and a buffer could have the same name, or two accessors could even have the same name.
    var name: String?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


// MARK: Nodes

/// Node
///
/// A node in the node hierarchy. When the node contains `skin`, all `mesh.primitives` **MUST** contain `JOINTS_0` and `WEIGHTS_0` attributes. A node **MAY** have either a `matrix` or any combination of `translation/rotation/scale` (TRS) properties. TRS properties are converted to matrices and postmultiplied in the `T * R * S` order to compose the transformation matrix; first the scale is applied to the vertices, then the rotation, and then the translation. If none are provided, the transform is the identity. When a node is targeted for animation (referenced by an animation.channel.target), `matrix` **MUST NOT** be present.
///
/// - Seealso: [Node](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-node)
struct GLTFNode: Sendable, Codable {
    /// The index of the camera referenced by this node.
    var camera: Int?
    
    
    /// The indices of this node’s children.
    ///
    /// - Each element in the array **MUST** be unique.
    /// - Each element in the array **MUST** be greater than or equal to 0.
    var children: [Int]?
    
    
    /// The index of the skin referenced by this node.
    ///
    /// When a skin is referenced by a node within a scene, all joints used by the skin **MUST** belong to the same scene. When defined, mesh **MUST** also be defined.
    var skin: Int?
    
    
    /// A floating-point 4x4 transformation matrix stored in column-major order.
    var matrix: [Float]? // = [1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1]
    
    
    /// The index of the mesh in this node.
    var mesh: Int?
    
    
    /// The node’s unit quaternion rotation in the order (x, y, z, w), where w is the scalar.
    var rotation: [Float]? // = [0,0,0,1]
    
    
    /// The node’s non-uniform scale, given as the scaling factors along the x, y, and z axes.
    var scale: [Float]? // = [1,1,1]
    
    
    /// The node’s translation along the x, y, and z axes.
    var translation: [Float]? // = [0,0,0]
    
    
    /// The weights of the instantiated morph target.
    ///
    /// The number of array elements **MUST** match the number of morph targets of the referenced mesh. When defined, mesh **MUST** also be defined.
    var weights: [Float]?
    
    
    /// The user-defined name of this object.
    ///
    /// This is not necessarily unique, e.g., an accessor and a buffer could have the same name, or two accessors could even have the same name.
    var name: String?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


// MARK: Samplers

enum GLTFTextureMagFilterMode: Int, Codable {
    case nearest = 9728
    case linear = 9729
}

enum GLTFTextureMinFilterMode: Int, Codable {
    case nearest = 9728
    case linear = 9729
    case nearestMipmapNearest = 9984
    case linearMipmapNearest = 9985
    case nearestMipmapLinear = 9986
    case linearMipmapLinear = 9987
}

enum GLTFTextureWrapMode: Int, Codable {
    case clampToEdge = 33071
    case mirroredRepeat = 33648
    case repeatPattern = 10497
}


/// Sampler
///
/// Texture sampler properties for filtering and wrapping modes.
///
/// - Seealso: [Sampler](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-sampler)
struct GLTFSampler: Sendable, Codable {
    /// Magnification filter.
    var magFilter: GLTFTextureMagFilterMode?
    
    
    /// Minification filter.
    var minFilter: GLTFTextureMinFilterMode?
    
    
    /// S (U) wrapping mode.
    ///
    /// All valid values correspond to WebGL enums.
    var wrapS: GLTFTextureWrapMode? // = .repeatPattern
    
    
    /// T (V) wrapping mode.
    var wrapT: GLTFTextureWrapMode? // = .repeatPattern
    
    
    /// The user-defined name of this object.
    /// This is not necessarily unique, e.g., an accessor and a buffer could have the same name, or two accessors could even have the same name.
    var name: String?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


// MARK: Scenes

/// Scene
///
/// The root nodes of a scene.
///
/// - Seealso: [Scene](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-scene)
struct GLTFScene: Sendable, Codable {
    /// The indices of each root node.
    ///
    /// - Each element in the array **MUST** be unique.
    /// - Each element in the array **MUST** be greater than or equal to 0.
    var nodes: [Int]?
    
    /// The user-defined name of this object.
    ///
    /// This is not necessarily unique, e.g., an accessor and a buffer could have the same name, or two accessors could even have the same name.
    var name: String?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


// MARK: Skins

/// Skin
///
/// Joints and matrices defining a skin.
///
/// - Seealso: [Skin](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-skin)
struct GLTFSkin: Sendable, Codable {
    /// The index of the accessor containing the floating-point 4x4 inverse-bind matrices.
    ///
    /// Its `accessor.count` property **MUST** be greater than or equal to the number of elements of the `joints` array. When undefined, each matrix is a 4x4 identity matrix.
    var inverseBindMatrices: Int?
    
    
    /// The index of the node used as a skeleton root.
    ///
    /// The node **MUST** be the closest common root of the joints hierarchy or a direct or indirect parent node of the closest common root.
    var skeleton: Int?
    
    
    /// Indices of skeleton nodes, used as joints in this skin.
    ///
    /// - Each element in the array **MUST** be unique.
    /// - Each element in the array **MUST** be greater than or equal to 0.
    var joints: [Int]
    
    
    /// The user-defined name of this object.
    ///
    /// This is not necessarily unique, e.g., an accessor and a buffer could have the same name, or two accessors could even have the same name.
    var name: String?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


// MARK: Textures

/// Texture
///
/// A texture and its sampler.
///
/// - Seealso: [Texture](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-texture)
struct GLTFTexture: Sendable, Codable {
    /// The index of the sampler used by this texture.
    ///
    /// When undefined, a sampler with repeat wrapping and auto filtering **SHOULD** be used.
    var sampler: Int?
    
    
    /// The index of the image used by this texture.
    /// When undefined, an extension or other mechanism **SHOULD** supply an alternate texture source, otherwise behavior is undefined.
    var source: Int?
    
    
    /// The user-defined name of this object.
    /// This is not necessarily unique, e.g., an accessor and a buffer could have the same name, or two accessors could even have the same name.
    var name: String?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
}


// MARK: GLTF

/// The root object for a glTF asset.
///
/// - Seealso: [glTF](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#reference-gltf)
struct GLTF: Sendable, Codable {
    /// Names of glTF extensions used in this asset.
    ///
    /// Each element in the array **MUST** be unique.
    var extensionsUsed: [String]?
    
    
    /// Names of glTF extensions required to properly load this asset.
    ///
    /// Each element in the array **MUST** be unique.
    var extensionsRequired: [String]?
    
    
    /// An array of accessors. An accessor is a typed view into a bufferView.
    var accessors: [GLTFAccessor]?
    
    
    /// An array of keyframe animations.
    var animations: [GLTFAnimation]?
    
    
    /// Metadata about the glTF asset.
    var asset: GLTFAsset
    
    
    /// An array of buffers.
    ///
    /// A buffer points to binary geometry, animation, or skins.
    var buffers: [GLTFBuffer]?
    
    
    /// An array of bufferViews.
    ///
    /// A bufferView is a view into a buffer generally representing a subset of the buffer.
    var bufferViews: [GLTFBufferView]?
    
    
    /// An array of cameras.
    ///
    /// A camera defines a projection matrix.
    var cameras: [GLTFCamera]?
    
    
    /// An array of images.
    ///
    /// An image defines data used to create a texture.
    var images: [GLTFImage]?
    
    
    /// An array of materials.
    ///
    /// A material defines the appearance of a primitive.
    var materials: [GLTFMaterial]?
    
    
    /// An array of meshes.
    ///
    /// A mesh is a set of primitives to be rendered.
    var meshes: [GLTFMesh]?
    
    
    /// An array of nodes.
    var nodes: [GLTFNode]?
    
    
    /// An array of samplers.
    /// A sampler contains properties for texture filtering and wrapping modes.
    var samplers: [GLTFSampler]?
    
    
    /// The index of the default scene.
    ///
    /// This property **MUST NOT** be defined, when scenes is undefined.
    var scene: Int?
    
    
    /// An array of scenes.
    var scenes: [GLTFScene]?
    
    
    /// An array of skins.
    ///
    /// A skin is defined by joints and matrices.
    var skins: [GLTFSkin]?
    
    
    /// An array of textures.
    var textures: [GLTFTexture]?
    
    
    /// JSON object with extension-specific objects.
    var extensions: GLTFExtension?
    
    
    /// Application-specific data.
    var extras: GLTFExtra?
    
    
    static func from(_ url: URL) async throws -> GLTF {
        // Text JSON
        if url.pathExtension.lowercased() == "gltf" {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(GLTF.self, from: data)
        }
        
        // Binary
        // Binary glTF Layout:
        // https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#binary-gltf-layout
        
        throw GLTFError.notSupported
    }
    
    
    static func from(_ data: Data) async throws -> GLTF {
        try JSONDecoder().decode(GLTF.self, from: data)
    }
}


struct GLTFData {
    var url: String
    var data: Data
}


fileprivate extension Data {
    mutating func write<SomeType: BinaryInteger>(_ value: SomeType) {
        withUnsafePointer(to: value) { pointer in
            append(Data(bytes: pointer, count: MemoryLayout<SomeType>.size))
        }
    }
}


//fileprivate struct DataReader {
//    private let data: Data
//    private(set) var offset: Int = 0
//    
//    
//    init(_ data: Data) {
//        self.data = data
//    }
//    
//    
//    mutating func read<SomeType>() throws -> SomeType {
//        let length = MemoryLayout<SomeType>.size
//        guard length > 0 else {
//            throw GLTFError.other("Strange data size")
//        }
//        
//        let endIndex = offset + length
//        guard offset >= 0 && endIndex <= data.count else {
//            throw GLTFError.other("Index out of range")
//        }
//        
//        let value = try data[data.startIndex.advanced(by: offset) ..< data.startIndex.advanced(by: endIndex)].withUnsafeBytes {
//            guard let value = $0.baseAddress?.loadUnaligned(as: SomeType.self) else {
//                throw GLTFError.other("Unwrap memory error")
//            }
//            
//            return value
//        }
//        
//        offset = endIndex
//        return value
//    }
//    
//    
//    mutating func readData<Integer: BinaryInteger>(ofLength length: Integer) throws -> Data {
//        guard length >= 0 else {
//            throw GLTFError.other("Strange data size")
//        }
//        
//        if length == 0 {
//            return Data()
//        }
//        
//        let endIndex = offset + Int(length)
//        guard offset >= 0 && endIndex <= data.count else {
//            throw GLTFError.other("Index out of range")
//        }
//        
//        let value = data[data.startIndex.advanced(by: offset) ..< data.startIndex.advanced(by: endIndex)]
//        
//        offset = endIndex
//        return value
//    }
//}


extension Data {
    mutating func alignSize(to alignment: Int = 4) {
        let dataLength = count
        if dataLength % alignment != 0 {
            let paddingLength = alignment - (dataLength % alignment)
            append(contentsOf: Array(repeating: 0, count: paddingLength))
        }
    }
}


func alignValue(_ value: Int, to alignment: Int = 4) -> Int {
    if value % alignment != 0 {
        let padding = alignment - (value % alignment)
        return value + padding
    }
    
    return value
}


struct GLTFLibrary: Sendable {
    var gltf: GLTF
    var data: [GLTFData] = []
    /// Actually there should be only one chunk of data, according to glTF specification
    var binaryChunks: [Data] = []
    
    
    static func from(_ url: URL) async throws -> GLTFLibrary {
        let data = try Data(contentsOf: url)
        return try await from(data)
    }
    
    
    static func from(_ data: Data) async throws -> GLTFLibrary {
        var reader = DataReader(data)
        
        // GLB header
        let magic: UInt32 = try reader.read()
        let version: UInt32 = try reader.read()
        let _: UInt32 = try reader.read()
        
        guard magic == 0x46546C67 else {
            throw GLTFError.other("Unknown header magic number")
        }
        
        guard version == 2 else {
            throw GLTFError.other("Unknown header version: \(version)")
        }
        
        // Json data
        //let jsonChunkLength: UInt32 = try reader.read()
        //let jsonChunkType: UInt32 = try reader.read()
        //let jsonData: Data = try reader.readData(ofLength: jsonChunkLength)
        //let gltf = try await GLTF.from(jsonData)
        
        
        throw GLTFError.notImplemented
    }
    
    
    /// Export to GLB data
    ///
    /// - Seealso: [Binary glTF Layout](https://registry.khronos.org/glTF/specs/2.0/glTF-2.0.html#binary-gltf-layout)
    func exportToGLB() async throws -> Data {
        // Binary data
        var binaryData = Data()
        for chunk in binaryChunks {
            // 4 bytes of length
            do {
                let length = UInt32(chunk.count)
                binaryData.write(length)
            }
            
            // 4 bytes of chunk type
            do {
                let chunkType: UInt32 = 0x004E4942
                binaryData.write(chunkType)
            }
            
            // data bytes with length aligned to 4
            do {
                binaryData.append(chunk)
                
                let dataLength = chunk.count
                if dataLength % 4 != 0 {
                    let paddingLength = 4 - (dataLength % 4)
                    binaryData.append(contentsOf: Array(repeating: 0, count: paddingLength))
                }
            }
        }
        
        
        // JSON data
        let jsonData = try JSONEncoder().encode(gltf)
        let jsonDataPadding = alignValue(jsonData.count) - jsonData.count
        
        
        // GLB data
        var glb = Data()
        
        
        // Header
        do {
            // 4 bytes of magic header
            do {
                guard let bytes = "glTF".data(using: .utf8) else {
                    throw GLTFError.other("Cannot convert the \"glTF\" string to UTF-8 data")
                }
                
                guard bytes.count == 4 else {
                    throw GLTFError.other("Cannot convert string to data")
                }
                
                glb.append(bytes)
            }
            
            
            // 4 bytes of version
            do {
                let version: [UInt8] = [2, 0, 0, 0]
                glb.append(Data(version))
            }
            
            
            // 4 bytes of total length
            do {
                let totalLength = 12 + 8 + jsonData.count + jsonDataPadding + binaryData.count
                if totalLength > UInt32.max {
                    throw GLTFError.other("Exceeded maximum 32-bit integer value for binary size")
                }
                glb.write(UInt32(totalLength))
            }
        }
        
        
        // json chunk
        do {
            // 4 bytes of length
            do {
                let length = UInt32(jsonData.count + jsonDataPadding)
                glb.write(length)
            }
            
            // 4 bytes of chunk type
            do {
                let chunkType: UInt32 = 0x4E4F534A
                glb.write(chunkType)
            }
            
            // data bytes with length aligned to 4
            do {
                glb.append(jsonData)
                
                if jsonDataPadding > 0 {
                    glb.append(contentsOf: Array(repeating: 0x20, count: jsonDataPadding))
                }
            }
        }
        
        
        // binary data chunk
        do {
            glb.append(binaryData)
        }
        
        
        //throw GLTFError.notImplemented
        return glb
    }
}
