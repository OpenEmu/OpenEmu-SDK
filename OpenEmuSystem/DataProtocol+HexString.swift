// Copyright (c) 2021, OpenEmu Team
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above copyright
//       notice, this list of conditions and the following disclaimer in the
//       documentation and/or other materials provided with the distribution.
//     * Neither the name of the OpenEmu Team nor the
//       names of its contributors may be used to endorse or promote products
//       derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
// LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

private let charA = UInt8(ascii: "A")
private let char0 = UInt8(ascii: "0")

private func itoh(_ value: UInt8) -> UInt8 {
    assert(value <= 0xF)
    return (value > 9) ? (charA + value - 10) : (char0 + value)
}

public extension DataProtocol {
    /// Returns a hexadecimal encoding of the receiver. Letters are uppercase.
    var hexString: String {
        let hexLen = self.count * 2
        var bytes: [UInt8] = []
        bytes.reserveCapacity(hexLen)
        
        for i in self {
            bytes.append(itoh((i >> 4) & 0xF))
            bytes.append(itoh(i & 0xF))
        }
        
        return String(bytes: bytes, encoding: .utf8)!
    }
}

public extension NSData {
    /// Returns a hexadecimal encoding of the receiver. Letters are uppercase.
    @objc(oe_hexStringRepresentation)
    var hexString: String {
        return (self as Data).hexString
    }
}
