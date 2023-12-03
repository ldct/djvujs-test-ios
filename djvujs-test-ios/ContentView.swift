//
//  ContentView.swift
//  djvujs-test-ios
//
//  Created by Li Xuanji on 2/12/23.
//

import SwiftUI
import JavaScriptCore
import CoreImage
import CoreImage.CIFilterBuiltins

struct PixelData {
    var a: UInt8
    var r: UInt8
    var g: UInt8
    var b: UInt8
}

func imageFromARGB32Bitmap(pixels: [PixelData], width: Int, height: Int) -> UIImage? {
    guard width > 0 && height > 0 else { return nil }
    guard pixels.count == width * height else { return nil }

    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
    let bitsPerComponent = 8
    let bitsPerPixel = 32

    var data = pixels // Copy to mutable []
    guard let providerRef = CGDataProvider(data: NSData(bytes: &data,
                            length: data.count * MemoryLayout<PixelData>.size)
        )
        else { return nil }

    guard let cgim = CGImage(
        width: width,
        height: height,
        bitsPerComponent: bitsPerComponent,
        bitsPerPixel: bitsPerPixel,
        bytesPerRow: width * MemoryLayout<PixelData>.size,
        space: rgbColorSpace,
        bitmapInfo: bitmapInfo,
        provider: providerRef,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
        )
        else { return nil }

    return UIImage(cgImage: cgim)
}


struct ImageData {
    let data: Data
    let size: CGSize
    
    init(context: JSContext, imageDataJSValue: JSValue) {
        let width = imageDataJSValue.forProperty("width").toInt32()
        let height = imageDataJSValue.forProperty("height").toInt32()
        
        let typedArray = imageDataJSValue.forProperty("data")!
        let typedArrayRef = typedArray.jsValueRef
        let byteLength = JSObjectGetTypedArrayByteLength(context.jsGlobalContextRef, typedArrayRef, nil)
        let buffer = typedArray.forProperty("buffer")!
        let ptr = JSObjectGetArrayBufferBytesPtr(context.jsGlobalContextRef, buffer.jsValueRef, nil)!
        self.data = Data(bytes: ptr, count: byteLength)
        self.size = CGSize(width: Int(width), height: Int(height))
        
        assert(byteLength == width*height*4)
    }
    
    var uiImage: UIImage {
        let arr = Array(data)
        var pixels = [PixelData]()

        assert(arr.count % 4 == 0)
        
        // loop through arr 4 at a time
        for i in stride(from: 0, to: arr.count, by: 4) {
            let pixel = PixelData(a: arr[i+3], r: arr[i], g: arr[i+1], b: arr[i+2])
            pixels.append(pixel)
        }
        
        return imageFromARGB32Bitmap(pixels: pixels, width: Int(self.size.width), height: Int(self.size.height))!
    }
}
struct ContentView: View {
    let context: JSContext = {
        let context = JSContext()!
        
        context.exceptionHandler = { context, exception in
            print(exception!.toString()!)
        }

        
        let url = Bundle.main.url(forResource: "core", withExtension: "js")!
        let data = try! Data.init(contentsOf: url)
        let str = String(data: data, encoding: .utf8)!
        context.evaluateScript(str)

        return context
    }()
    
    let specContents: Data = {
        let url = Bundle.main.url(forResource: "DjVu3Spec", withExtension: "djvu")!
        let data = try! Data.init(contentsOf: url)
        return data
    }()
    
    let specAB: JSValue?

    func getImageDataForPage(_ pageNum: Int) -> ImageData {
        let sizeFunc = context.objectForKeyedSubscript("getID")!
        let imageData: JSValue = sizeFunc.call(withArguments: [specAB, pageNum])!
        
        return ImageData(context: context, imageDataJSValue: imageData)
    }
    
    init() {
        let contents = specContents
        let ctx = context
        
        let ptr: UnsafeMutableBufferPointer<UInt8> = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: contents.count)

        // copy Data into ptr
        contents.withUnsafeBytes { (contentsPtr: UnsafePointer<UInt8>) -> Void in
            let _ = ptr.initialize(from: UnsafeBufferPointer(start: contentsPtr, count: contents.count))
        }

        var exception : JSValueRef?
        let deallocator: JSTypedArrayBytesDeallocator = { ptr, deallocatorContext in
            // deallocate previous allocated ptr.
            ptr?.deallocate()
        }

        let arrayBufferRef = JSObjectMakeArrayBufferWithBytesNoCopy(
            ctx.jsGlobalContextRef,
            ptr.baseAddress,
            contents.count,
            deallocator,
            nil,
            &exception)

        if exception != nil {
            ctx.exception = JSValue(jsValueRef: exception, in: ctx)
            specAB = nil
        } else {
            specAB = JSValue(jsValueRef: arrayBufferRef, in: ctx)
        }
        let id = getImageDataForPage(3)
        uiImage = id.uiImage
    }
    
    var uiImage: UIImage?
    @State private var image: Image?
    
    @State private var desiredPageNum: Int = 1

    var body: some View {
        VStack {
            image?
                .resizable()
                .scaledToFit()
            HStack {
                Button(action: {
                    desiredPageNum -= 1
                    loadImage()
                }) {
                    Image(systemName: "chevron.left")
                }
                Text("Page \(desiredPageNum)")
                Button(action: {
                    desiredPageNum += 1
                    loadImage()
                }) {
                    Image(systemName: "chevron.right")
                }
            }
        }
        .onAppear(perform: loadImage)
    }

    func loadImage() {
        print("loadImage called")
        let id = getImageDataForPage(desiredPageNum)
        image = Image(uiImage: id.uiImage)
    }
}

#Preview {
    ContentView()
}
