// CHECKITOUT: code that you add here will be prepended to all shaders
const CLUSTER_X : u32 = 16u;
const CLUSTER_Y : u32 = 9u;
const CLUSTER_Z : u32 = 24u;
const MAX_LIGHTS_PER_CLUSTER : u32 = 1024u;
const SQUARE_R : f32 = ${lightRadius} * ${lightRadius};

struct Light {
    pos: vec3f,
    color: vec3f
}

struct LightSet {
    numLights: u32,
    lights: array<Light>
}

struct Cluster {
    numLights : u32,
    lights : array<u32, MAX_LIGHTS_PER_CLUSTER>
}

struct ClusterSet {
    numClusters : u32,
    clusters : array<Cluster>
}

struct CameraUniforms {
    viewProjMat : mat4x4f,
    invProjMat: mat4x4f,
    viewMat: mat4x4f,
    invViewMat: mat4x4f,
    screenSize : vec2f,
    zNear : f32,
    zFar : f32
}

// CHECKITOUT: this special attenuation function ensures lights don't affect geometry outside the maximum light radius
fn rangeAttenuation(distance: f32) -> f32 {
    return clamp(1.f - pow(distance / ${lightRadius}, 4.f), 0.f, 1.f) / (distance * distance);
}

fn calculateLightContrib(light: Light, posWorld: vec3f, nor: vec3f) -> vec3f {
    let vecToLight = light.pos - posWorld;
    let distToLight = length(vecToLight);

    let lambert = max(dot(nor, normalize(vecToLight)), 0.f);
    return light.color * lambert * rangeAttenuation(distToLight);
}

