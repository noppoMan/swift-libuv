//
//  support.swift
//  Suv
//
//  Created by Yuki Takei on 1/23/16.
//  Copyright © 2016 MikeTOKYO. All rights reserved.
//

import CLibUv

let alloc_buffer: @convention(c) (UnsafeMutablePointer<uv_handle_t>, ssize_t, UnsafeMutablePointer<uv_buf_t>) -> Void = { (handle, suggestedSize, buf) in
    buf.pointee = uv_buf_init(UnsafeMutablePointer(allocatingCapacity: suggestedSize), UInt32(suggestedSize))
}

internal func close_handle<T>(req: UnsafeMutablePointer<T>){
    if uv_is_closing(UnsafeMutablePointer(req)) == 1 {
        return
    }
    uv_close(UnsafeMutablePointer<uv_handle_t>(req)) {
        dealloc($0)
    }
}

// cleanup and free
func fs_req_cleanup(req: UnsafeMutablePointer<uv_fs_t>) {
    uv_fs_req_cleanup(req)
    dealloc(req)
}

func dealloc<T>(ponter: UnsafeMutablePointer<T>, capacity: Int? = nil){
    ponter.deinitialize()
    ponter.deallocateCapacity(capacity ?? sizeof(T))
}

internal func dict2ArrayWithEqualSeparator(dict: [String: String]) -> [String] {
    var envs = [String]()
    for (k,v) in dict {
        envs.append("\(k)=\(v)")
    }
    return envs
}

final class Box<A> {
    let unbox: A
    init(_ value: A) { unbox = value }
}

func retainedVoidPointer<A>(x: A?) -> UnsafeMutablePointer<Void> {
    guard let value = x else { return UnsafeMutablePointer<Void>(allocatingCapacity: 0) }
    let unmanaged = OpaquePointer(bitPattern: Unmanaged.passRetained(Box(value)))
    return UnsafeMutablePointer(unmanaged)
}

func releaseVoidPointer<A>(x: UnsafeMutablePointer<Void>) -> A? {
    guard x != nil else { return nil }
    return Unmanaged<Box<A>>.fromOpaque(OpaquePointer(x)).takeRetainedValue().unbox
}

func unsafeFromVoidPointer<A>(x: UnsafeMutablePointer<Void>) -> A? {
    guard x != nil else { return nil }
    return Unmanaged<Box<A>>.fromOpaque(OpaquePointer(x)).takeUnretainedValue().unbox
}