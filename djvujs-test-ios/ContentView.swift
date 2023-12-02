//
//  ContentView.swift
//  djvujs-test-ios
//
//  Created by Li Xuanji on 2/12/23.
//

import SwiftUI
import JavaScriptCore


struct ContentView: View {
    let context: JSContext = {
        let context = JSContext()!
        
        context.exceptionHandler = { context, exception in
            print(exception!.toString())
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
        
        
        let sizeFunc = context.objectForKeyedSubscript("arrayBufferToAnInt")!
        let result3 = sizeFunc.call(withArguments: [specAB])!
        print(result3.toInt32())


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
