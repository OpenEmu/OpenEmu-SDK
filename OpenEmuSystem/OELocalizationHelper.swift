// Copyright (c) 2022, OpenEmu Team
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

@objc
@objcMembers
public class OELocalizationHelper: NSObject {
    
    @objc public enum OERegion: Int {
        @objc(OERegionNA)
        case na = 0
        @objc(OERegionJPN)
        case jpn = 1
        @objc(OERegionEU)
        case eu = 2
        @objc(OERegionOther)
        case other = 3
        
        public var name: String {
            switch self {
            case .eu:
                return NSLocalizedString("Europe", comment: "")
            case .na:
                return NSLocalizedString("North America", comment: "")
            case .jpn:
                return NSLocalizedString("Japan", comment: "")
            case .other:
                return NSLocalizedString("Other Region", comment: "")
            }
        }
    }
    
    public static let OERegionKey = "region"
    
    @objc(sharedHelper)
    public static let shared = OELocalizationHelper()
    
    public private(set) var region: OERegion = .other
    
    private override init() {
        super.init()
        updateRegion()
        
        UserDefaults.standard.addObserver(self, forKeyPath: Self.OERegionKey, options: [], context: nil)
    }
    
    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: Self.OERegionKey)
    }
    
    override public func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        updateRegion()
    }
    
    private func updateRegion() {
        if let value = UserDefaults.standard.value(forKey: Self.OERegionKey) as? Int {
            region = OELocalizationHelper.OERegion(rawValue: value) ?? .other
        }
        else if let regionCode = Locale.current.regionCode {
            
            if OERegionCodes.europe.contains(regionCode) {
                region = .eu
            }
            else if OERegionCodes.northAmerica.contains(regionCode) {
                region = .na
            }
            else if ["JP", "HK", "TW"].contains(regionCode) {
                region = .jpn
            }
            else {
                region = .other
            }
        }
        else {
            region = .other
        }
    }
    
    // MARK: - Region Codes
    
    private enum OERegionCodes {
        static let africa = ["AO","BF","BI","BJ","BW","CD","CF","CG","CI","CM","CV","DJ","DZ","EG","EH","ER","ET","GA","GH","GM","GN","GQ","GW","KE","KM","LR","LS","LY","MA","MG","ML","MR","MU","MW","MZ","NA","NE","NG","RE","RW","SC","SD","SH","SL","SN","SO","SS","ST","SZ","TD","TG","TN","TZ","UG","YT","ZA","ZM","ZW"]
        static let antarctica = ["AQ","BV","GS","HM","TF"]
        static let asia = ["AE","AF","AM","AZ","BD","BH","BN","BT","CC","CN","CX","CY","GE","HK","ID","IL","IN","IO","IQ","IR","JO","JP","KG","KH","KP","KR","KW","KZ","LA","LB","LK","MM","MN","MO","MV","MY","NP","OM","PH","PK","PS","QA","SA","SG","SY","TH","TJ","TL","TM","TR","TW","UZ","VN","YE"]
        static let europe = ["AD","AL","AT","AX","BA","BE","BG","BY","CH","CZ","DE","DK","EE","ES","FI","FO","FR","GB","GG","GI","GR","HR","HU","IE","IM","IS","IT","JE","LI","LT","LU","LV","MC","MD","ME","MK","MT","NL","NO","PL","PT","RO","RS","RU","SE","SI","SJ","SK","SM","UA","VA"]
        static let northAmerica = ["AG","AI","AW","BB","BL","BM","BQ","BS","BZ","CA","CR","CU","CW","DM","DO","GD","GL","GP","GT","HN","HT","JM","KN","KY","LC","MF","MQ","MS","MX","NI","PA","PM","PR","SV","SX","TC","TT","US","VC","VG","VI"]
        static let southAmerica = ["AR","BO","BR","CL","CO","EC","FK","GF","GY","PE","PY","SR","UY","VE"]
        static let oceania = ["AS","AU","CK","FJ","FM","GU","KI","MH","MP","NC","NF","NR","NU","NZ","PF","PG","PN","PW","SB","TK","TO","TV","UM","VU","WF","WS"]
    }
}

@objc public extension OELocalizationHelper {
    
    var regionName: String {
        return region.name
    }
    
    var isRegionEU: Bool {
        region == .eu
    }
    
    var isRegionNA: Bool {
        region == .na
    }
    
    var isRegionJPN: Bool {
        region == .jpn
    }
    
    @available(*, deprecated, renamed: "isRegionJPN")
    var isRegionJAP: Bool {
        isRegionJPN
    }
}
