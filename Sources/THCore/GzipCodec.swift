import Foundation
import Compression

public enum GzipCodec {
    public static func compress(_ data: Data) throws -> Data {
        try transform(data, operation: COMPRESSION_STREAM_ENCODE)
    }
    public static func decompress(_ data: Data) throws -> Data {
        try transform(data, operation: COMPRESSION_STREAM_DECODE)
    }

    private static func transform(_ data: Data, operation: compression_stream_operation) throws -> Data {
        let bufferSize = 64 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        // Allocate a single dummy byte as a valid (non-nil) src pointer for init.
        let dummy = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        defer { dummy.deallocate() }
        dummy.pointee = 0

        var stream = compression_stream(
            dst_ptr: buffer, dst_size: bufferSize,
            src_ptr: UnsafePointer<UInt8>(dummy),
            src_size: 0, state: nil
        )
        var status = compression_stream_init(&stream, operation, COMPRESSION_ZLIB)
        guard status != COMPRESSION_STATUS_ERROR else { throw GzipError.initFailed }
        defer { compression_stream_destroy(&stream) }

        var output = Data()
        return try data.withUnsafeBytes { raw -> Data in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw GzipError.badInput
            }
            stream.src_ptr = base
            stream.src_size = data.count
            stream.dst_ptr = buffer
            stream.dst_size = bufferSize
            let flags = Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
            repeat {
                status = compression_stream_process(&stream, flags)
                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    let count = bufferSize - stream.dst_size
                    if count > 0 { output.append(buffer, count: count) }
                    stream.dst_ptr = buffer
                    stream.dst_size = bufferSize
                default:
                    throw GzipError.processFailed
                }
            } while status == COMPRESSION_STATUS_OK
            return output
        }
    }
}

public enum GzipError: Error { case initFailed, badInput, processFailed }