import Foundation
import Security

public enum ULID {
    private static let alphabet: [Character] = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    public static func generate(at ms: UInt64, randomness: [UInt8]? = nil) -> String {
        var ts = ms
        var chars = [Character](repeating: "0", count: 26)
        // Timestamp: 10 chars × 5 bits = 50 bits, only lower 48 bits used (ms since epoch).
        for i in (0..<10).reversed() {
            chars[i] = alphabet[Int(ts & 0x1F)]
            ts >>= 5
        }
        let rng = randomness ?? randomBytes(10)
        // Randomness: 16 chars × 5 bits = 80 bits, packed from a 10-byte stream.
        var bitPos = 0
        for i in 0..<16 {
            let byteIdx = bitPos / 8
            let bitInByte = bitPos % 8
            var val = Int(rng[byteIdx]) >> bitInByte
            if bitInByte > 3 && byteIdx + 1 < rng.count {
                val |= Int(rng[byteIdx + 1]) << (8 - bitInByte)
            }
            chars[10 + i] = alphabet[val & 0x1F]
            bitPos += 5
        }
        return String(chars)
    }

    public static func parse(_ s: String) throws -> (timestamp: UInt64, randomness: [UInt8]) {
        guard s.count == 26 else { throw ULIDError.badLength }
        var ts: UInt64 = 0
        for i in 0..<10 {
            guard let v = decodeChar(s[s.index(s.startIndex, offsetBy: i)]) else { throw ULIDError.invalidChar }
            ts = (ts << 5) | UInt64(v)
        }
        var random = [UInt8](repeating: 0, count: 10)
        var bitPos = 0
        for i in 0..<16 {
            let idx = 10 + i
            guard let v = decodeChar(s[s.index(s.startIndex, offsetBy: idx)]) else { throw ULIDError.invalidChar }
            let byteIdx = bitPos / 8
            let bitInByte = bitPos % 8
            random[byteIdx] |= UInt8(truncatingIfNeeded: (v & 0x1F) << bitInByte)
            if bitInByte > 3 && byteIdx + 1 < random.count {
                random[byteIdx + 1] |= UInt8((v & 0x1F) >> (8 - bitInByte))
            }
            bitPos += 5
        }
        return (ts, random)
    }

    private static func randomBytes(_ n: Int) -> [UInt8] {
        var b = [UInt8](repeating: 0, count: n)
        _ = SecRandomCopyBytes(kSecRandomDefault, n, &b)
        return b
    }

    private static func decodeChar(_ c: Character) -> Int? {
        alphabet.firstIndex(of: Character(String(c).uppercased()))
    }
}

public enum ULIDError: Error { case badLength, invalidChar }