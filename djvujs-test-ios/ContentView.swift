//
//  ContentView.swift
//  djvujs-test-ios
//
//  Created by Li Xuanji on 2/12/23.
//

import SwiftUI
import JavaScriptCore

struct ImageData {
    let data: Data
    let size: CGSize
    
    init(context: JSContext, imageDataJSValue: JSValue) {
        let width = imageDataJSValue.forProperty("width").toInt32()
        let height = imageDataJSValue.forProperty("height").toInt32()
        
        let typedArray = imageDataJSValue.forProperty("data")!
        let typedArrayRef = typedArray.jsValueRef
        let byteLength = JSObjectGetTypedArrayByteLength(context.jsGlobalContextRef, typedArrayRef, nil)
        print(byteLength)
        let buffer = typedArray.forProperty("buffer")!
        let ptr = JSObjectGetArrayBufferBytesPtr(context.jsGlobalContextRef, buffer.jsValueRef, nil)!
        self.data = Data(bytes: ptr, count: byteLength)
        self.size = CGSize(width: Int(width), height: Int(height))
        
        assert(byteLength == width*height*4)
    }
}
struct ContentView: View {
    lazy var context: JSContext = {
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
    
    lazy var specAB: JSValue? = {
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
            return nil
        }

        return JSValue(jsValueRef: arrayBufferRef, in: ctx)
    }()

    init() {
        print("xuanji06 hi")
        
        
        let sizeFunc = context.objectForKeyedSubscript("firstPage")!
        let imageData: JSValue = sizeFunc.call(withArguments: [specAB!])!
        
        let id = ImageData(context: context, imageDataJSValue: imageData)

//        let a = Array(d)
//        var total = 0
//        a.forEach {
//            total += Int($0)
//            total = total % 137
//        }
//        print(total)
        //        let arr = (result3.toArray()!) as! [Int]
////
//        let width = arr[0]
//        let height = arr[1]
//        
//        let rest = arr.dropFirst(2)
//        
//        print(width*height*4, rest.count)

//        let url2 = Bundle.main.url(forResource: "DjVu3Spec", withExtension: "djvu")!
//        let data = try! Data.init(contentsOf: url2)
//        let str = data.base64EncodedString(options: NSData.Base64EncodingOptions.init(rawValue: 0))
    }
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")        }
        .padding()
    }
}

#Preview {
    ContentView()
}
