//
//  main.metal
//  WAD Editor
//
//  Created by Evgenij Lutz on 21.02.25.
//

#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;


// MARK: - From LemurC.Layouts

struct MeshUniform {
    simd_float4x4 model;
};

struct WeightedMeshUniform {
    simd_float4x4 model0;
    simd_float4x4 model1;
};

struct SceneUniform {
    simd_float4x4 viewProjection;
    simd_float3 ambient;
};


// MARK: - Intermediate

struct fragment_out {
    half4 finalColor [[ color(0) ]];
};


// MARK: - Standard with normals

struct vertex_input {
    float3 position [[ attribute(0) ]];
    float2 uv [[ attribute(1) ]];
    float3 normal [[ attribute(2) ]];
};

struct vertex_out {
    float4 position [[ position ]];
    float2 uv;
};

vertex vertex_out mesh_vertex(vertex_input input [[ stage_in ]],
                              constant MeshUniform& meshUniforms [[ buffer(1) ]],
                              constant SceneUniform& sceneUniforms [[ buffer(2) ]]) {
    vertex_out out;
    out.position = sceneUniforms.viewProjection * meshUniforms.model * float4(input.position, 1.0f);
    out.uv = input.uv;
    
    return out;
}

fragment fragment_out mesh_fragment(vertex_out in [[ stage_in ]],
                                    sampler textureSampler [[ sampler(0) ]],
                                    texture2d<half> albedoMap [[ texture(0) ]],
                                    constant SceneUniform& sceneUniforms [[ buffer(0) ]]) {
    half4 albedo = albedoMap.sample(textureSampler, in.uv);

    fragment_out out;
    out.finalColor = albedo;
    return out;
}


// MARK: - Shaded

struct ShadedVertex {
    float3 position [[ attribute(0) ]];
    float2 uv [[ attribute(1) ]];
    float shade [[ attribute(2) ]];
};

struct ShadedVertexOut {
    float4 position [[ position ]];
    float2 uv;
    float shade;
};

vertex ShadedVertexOut shadedMesh_vf(ShadedVertex input [[ stage_in ]],
                                     constant MeshUniform& meshUniforms [[ buffer(1) ]],
                                     constant SceneUniform& sceneUniforms [[ buffer(2) ]]) {
    ShadedVertexOut out;
    out.position = sceneUniforms.viewProjection * meshUniforms.model * float4(input.position, 1.0f);
    out.uv = input.uv;
    out.shade = input.shade;
    
    return out;
}

fragment fragment_out shadedMesh_ff(ShadedVertexOut in [[ stage_in ]],
                                    sampler textureSampler [[ sampler(0) ]],
                                    texture2d<half> albedoMap [[ texture(0) ]],
                                    constant SceneUniform& sceneUniforms [[ buffer(0) ]]) {
    half4 albedo = albedoMap.sample(textureSampler, in.uv);
    
    albedo.rgb = albedo.rgb * in.shade;
    
    fragment_out out;
    out.finalColor = albedo;
    return out;
}


// MARK: Jointed

struct WeightedVertexInput {
    float3 position [[ attribute(0) ]];
    float2 uv [[ attribute(1) ]];
    float3 normal [[ attribute(2) ]];
    
    float3 offset [[ attribute(3) ]];
    float weight0 [[ attribute(4) ]];
    float weight1 [[ attribute(5) ]];
};

vertex vertex_out weightedMesh_vf(WeightedVertexInput input [[ stage_in ]],
                                  constant WeightedMeshUniform& meshUniform [[ buffer(1) ]],
                                  constant SceneUniform& sceneUniform [[ buffer(2) ]]) {
    vertex_out out;
    
    auto position = float4(input.position + input.offset, 1.0f);
    auto position0 = meshUniform.model0 * position * input.weight0;
    auto position1 = meshUniform.model1 * position * input.weight1;
    
    out.position = sceneUniform.viewProjection * (position0 + position1);
    out.uv = input.uv;
    
    return out;
}

fragment fragment_out weightedMesh_ff(vertex_out in [[ stage_in ]],
                                      sampler textureSampler [[ sampler(0) ]],
                                      texture2d<half> albedoMap [[ texture(0) ]],
                                      constant SceneUniform& sceneUniforms [[ buffer(0) ]]) {
    half4 albedo = albedoMap.sample(textureSampler, in.uv);
    
    fragment_out out;
    out.finalColor = albedo;
    return out;
}
