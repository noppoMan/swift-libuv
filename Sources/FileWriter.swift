//
//  FileWriter.swift
//  Suv
//
//  Created by Yuki Takei on 1/23/16.
//  Copyright © 2016 MikeTOKYO. All rights reserved.
//

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

import CLibUv

public enum FsWriteResult {
    case End(Int)
    case Error(SuvError)
}

class FileWriterContext {
    var writeReq: UnsafeMutablePointer<uv_fs_t> = nil
    
    var onWrite: (FsWriteResult) -> Void = {_ in }
    
    var bytesWritten: Int64 = 0
    
    var data = Buffer()
    
    var buf: uv_buf_t? = nil
    
    let loop: Loop
    
    let fd: Int32
    
    let offset: Int  // Not implemented yet
    
    var length: Int? // Not implemented yet
    
    var position: Int
    
    var curPos: Int {
        return position + Int(bytesWritten)
    }
    
    init(loop: Loop = Loop.defaultLoop, fd: Int32, offset: Int, length: Int? = nil, position: Int, completion: FsWriteResult -> Void){
        self.loop = loop
        self.fd = fd
        self.offset = offset
        self.length = length
        self.position = position
        self.onWrite = completion
    }
}

class FileWriter {
    
    var context: UnsafeMutablePointer<FileWriterContext>
    
    init(loop: Loop = Loop.defaultLoop, fd: Int32, offset: Int, length: Int? = nil, position: Int, completion: FsWriteResult -> Void){
        context = UnsafeMutablePointer<FileWriterContext>.alloc(1)
        context.initialize(
            FileWriterContext(
                loop: loop,
                fd: fd,
                offset: offset,
                length: length,
                position: position,
                completion: completion
            )
        )
    }
    
    func write(data: Buffer){
        if(data.bytes.count <= 0) {
            destroyContext(context)
            context = nil
            return context.memory.onWrite(.End(0 + context.memory.offset))
        }
        context.memory.data = data
        attemptWrite(context)
    }
}

func destroyContext(context: UnsafeMutablePointer<FileWriterContext>){
    context.destroy()
    context.dealloc(1)
}

func attemptWrite(context: UnsafeMutablePointer<FileWriterContext>){
    let writeReq = UnsafeMutablePointer<uv_fs_t>.alloc(sizeof(uv_fs_t))
    
    var bytes = context.memory.data.bytes.map { Int8(bitPattern: $0) }
    context.memory.buf = uv_buf_init(&bytes, UInt32(context.memory.data.bytes.count))
    
    writeReq.memory.data = UnsafeMutablePointer(context)
    
    let r = uv_fs_write(context.memory.loop.loopPtr, writeReq, uv_file(context.memory.fd), &context.memory.buf!, UInt32(context.memory.buf!.len), Int64(context.memory.curPos)) { req in
        onWriteEach(req)
    }
    
    if r < 0 {
        defer {
            fs_req_cleanup(writeReq)
            destroyContext(context)
        }
        return context.memory.onWrite(.Error(SuvError.UVError(code: r)))
    }
}

func onWriteEach(req: UnsafeMutablePointer<uv_fs_t>){
    defer {
        fs_req_cleanup(req)
    }
    
    var context = UnsafeMutablePointer<FileWriterContext>(req.memory.data)
    
    if(req.memory.result < 0) {
        defer {
            destroyContext(context)
            context = nil
        }
        let e = SuvError.UVError(code: Int32(req.memory.result))
        return context.memory.onWrite(.Error(e))
    }
    
    if(req.memory.result == 0) {
        defer {
            destroyContext(context)
            context = nil
        }
        return context.memory.onWrite(.End(context.memory.curPos))
    }
    
    context.memory.bytesWritten += req.memory.result
    
    if Int(context.memory.bytesWritten) >= Int(context.memory.data.bytes.count) {
        defer {
            destroyContext(context)
            context = nil
        }
        return context.memory.onWrite(.End(context.memory.curPos))
    }
    
    attemptWrite(context)
}