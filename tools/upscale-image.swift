import AppKit
import Metal
import MetalFX
import CoreImage
// upscale <in.png> <out.png> <factor>  — MetalFX spatial (edge-aware) upscaling in 2× steps + gentle sharpening, alpha preserved.
let a = CommandLine.arguments
let dev = MTLCreateSystemDefaultDevice()!
let q = dev.makeCommandQueue()!
let ci = CIContext(mtlDevice: dev, options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])
let original = CIImage(contentsOf: URL(fileURLWithPath: a[1]))!
var img = original
let target = Double(a[3])!
func tex(_ w: Int, _ h: Int, _ usage: MTLTextureUsage) -> MTLTexture {
    let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: w, height: h, mipmapped: false)
    d.usage = usage; d.storageMode = .private; return dev.makeTexture(descriptor: d)!
}
func step(_ input: CIImage, _ f: Double) -> CIImage {
    let iw = Int(input.extent.width), ih = Int(input.extent.height)
    let ow = Int(Double(iw) * f), oh = Int(Double(ih) * f)
    let src = tex(iw, ih, [.shaderRead, .shaderWrite, .renderTarget])
    let cb0 = q.makeCommandBuffer()!
    ci.render(input.transformed(by: CGAffineTransform(translationX: -input.extent.minX, y: -input.extent.minY)), to: src, commandBuffer: cb0, bounds: CGRect(x: 0, y: 0, width: iw, height: ih), colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)
    cb0.commit(); cb0.waitUntilCompleted()
    let desc = MTLFXSpatialScalerDescriptor()
    desc.inputWidth = iw; desc.inputHeight = ih; desc.outputWidth = ow; desc.outputHeight = oh
    desc.colorTextureFormat = .rgba16Float; desc.outputTextureFormat = .rgba16Float; desc.colorProcessingMode = .perceptual
    let scaler = desc.makeSpatialScaler(device: dev)!
    let dst = tex(ow, oh, scaler.outputTextureUsage.union(.shaderRead))
    scaler.colorTexture = src; scaler.outputTexture = dst; scaler.inputContentWidth = iw; scaler.inputContentHeight = ih
    let cb = q.makeCommandBuffer()!; scaler.encode(commandBuffer: cb); cb.commit(); cb.waitUntilCompleted()
    return CIImage(mtlTexture: dst, options: [.colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])!.oriented(.downMirrored)
}
var remaining = target
while remaining > 1.001 { let f = min(2.0, remaining); img = step(img, f); remaining /= f }
let sharpRGB = img.applyingFilter("CIUnsharpMask", parameters: [kCIInputRadiusKey: 2.0, kCIInputIntensityKey: 0.45])
// MetalFX drops alpha: take the edge from a Lanczos-scaled alpha and keep the colour premultiplied-valid.
let lzA = original.applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: target, kCIInputAspectRatioKey: 1.0]).applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: 2.5]).cropped(to: sharpRGB.extent)
let k = CIColorKernel(source: "kernel vec4 k(__sample c, __sample m){ float a = clamp(m.a,0.0,1.0); return vec4(min(c.rgb, vec3(a)), a); }")!
let sharp = k.apply(extent: sharpRGB.extent, arguments: [sharpRGB, lzA])!
let cg = ci.createCGImage(sharp, from: sharp.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)!
try! NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
print("ok", cg.width, cg.height)
