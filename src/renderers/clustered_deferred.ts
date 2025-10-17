import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
    // TODO-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution

    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    gbufferBindGroupLayout: GPUBindGroupLayout;
    gbufferBindGroup: GPUBindGroup;


    gAlbedo: GPUTexture;
    gAlbedoView: GPUTextureView;
    gNormal: GPUTexture;
    gNormalView: GPUTextureView;
    gSampler: GPUSampler;

    gWorldZ: GPUTexture;
    gWorldZView: GPUTextureView;

    scenePipeline: GPURenderPipeline;
    gbufferPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);

        // TODO-3: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // you'll need two pipelines: one for the G-buffer pass and one for the fullscreen pass
        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "scene uniforms bind group layout",
            entries: [
                { // camera
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT | GPUShaderStage.VERTEX,
                    buffer:{ type: "uniform" }
                },
                { // lightSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                { // clusterSet
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                }
            ]
        });
        
        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "scene uniforms bind group",
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer }
                },
                {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                },
                {
                    binding: 2,
                    resource: { buffer: this.lights.clusterSetBuffer }
                }
            ]
        });

        // ---------------------------------------------------------------------
        // Create G-buffer textures (albedo, normal, viewZ) and sampler
        // ---------------------------------------------------------------------
        this.gAlbedo = renderer.device.createTexture({
            label: "gAlbedo",
            size : [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gAlbedoView = this.gAlbedo.createView();

        this.gNormal = renderer.device.createTexture({
            label: "gNormal",
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gNormalView = this.gNormal.createView();

        this.gWorldZ = renderer.device.createTexture({
            label: "gViewZ",
            size: [renderer.canvas.width, renderer.canvas.height],
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.gWorldZView = this.gWorldZ.createView();
        
        this.gSampler = renderer.device.createSampler();

        this.gbufferBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "gbuffer bind group layout",
            entries: [
                { // gAlbedo
                    binding: 0,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {}
                },
                { // gNormal
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: {}
                },
                { // gViewZ
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    texture: { sampleType: "depth" }
                },
                { // sampler
                    binding: 3,
                    visibility: GPUShaderStage.FRAGMENT,
                    sampler: { type: 'non-filtering' }
                }
            ]
        });
        
        // ---------------------------------------------------------------------
        // Depth texture for geometry pass
        // ---------------------------------------------------------------------
        this.gbufferBindGroup = renderer.device.createBindGroup({
            label: "gbuffer bind group",
            layout: this.gbufferBindGroupLayout,
            entries: [
                { binding: 0, resource: this.gAlbedoView },
                { binding: 1, resource: this.gNormalView },
                { binding: 2, resource: this.gWorldZView },
                { binding: 3, resource: this.gSampler }
            ]
        });

        this.scenePipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "clustered deferred fullscreen layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    this.gbufferBindGroupLayout
                ]
            }),
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "fullscreen vert",
                    code: shaders.clusteredDeferredFullscreenVertSrc
                }),
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "fullscreen frag",
                    code: shaders.clusteredDeferredFullscreenFragSrc
                }),
                targets: [
                    {
                        format: renderer.canvasFormat
                    }
                ]
            }
        });
        // ---------------------------------------------------------------------
        // Create G-buffer pipeline (geometry pass)
        // ---------------------------------------------------------------------
        this.gbufferPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "gbuffer pipeline layout",
                bindGroupLayouts: [
                    this.sceneUniformsBindGroupLayout,
                    renderer.modelBindGroupLayout,
                    renderer.materialBindGroupLayout
                ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "gbuffer vertex shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "gbuffer fragment shader",
                    code: shaders.clusteredDeferredFragSrc
                }),
                targets: [
                    { format: "rgba16float" }, // albedo
                    { format: "rgba16float" } //normal
                ]
            }
        });

    }

    override draw() {
        // TODO-3: run the Forward+ rendering pass:
        // - run the clustering compute shader
        // - run the G-buffer pass, outputting position, albedo, and normals
        // - run the fullscreen pass, which reads from the G-buffer and performs lighting calculations
        const encoder = renderer.device.createCommandEncoder();
        const canvasTextureView = renderer.context.getCurrentTexture().createView();
        
        this.lights.doLightClustering(encoder);

        const gpass = encoder.beginRenderPass({
            label: "gbuffer pass",
            colorAttachments: [
                {
                    view: this.gAlbedoView,
                    clearValue: [0.0, 0.0, 0.0, 1.0],
                    loadOp: "clear",
                    storeOp: "store"
                },
                {
                    view: this.gNormalView,
                    clearValue: [0.5, 0.5, 1.0, 0.0], 
                    loadOp: "clear",
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.gWorldZView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        });
        gpass.setPipeline(this.gbufferPipeline);
        gpass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);

        this.scene.iterate(node => {
            gpass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            gpass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            gpass.setVertexBuffer(0, primitive.vertexBuffer);
            gpass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            gpass.drawIndexed(primitive.numIndices);
        });

        gpass.end();

        // 3) Fullscreen lighting pass (read from G-buffer + clusters)
        const fpass = encoder.beginRenderPass({
            label: "clustered deferred fullscreen pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
                    clearValue: [0.0, 0.0, 0.0, 1.0],
                    loadOp: "clear",
                    storeOp: "store"
                }
            ]
        });

        fpass.setPipeline(this.scenePipeline);

        fpass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);
        fpass.setBindGroup(shaders.constants.bindGroup_gbuffer, this.gbufferBindGroup);

        fpass.draw(3, 1, 0, 0);

        fpass.end();

        renderer.device.queue.submit([encoder.finish()]);
    }
}

