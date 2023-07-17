//
//  Extensions.swift
//  pitwall-ios
//
//  Created by Robin on 22/5/23.
//

import Foundation
import SceneKit

extension String {
    func base64Encoded() -> String? {
        return data(using: .utf8)?.base64EncodedString()
    }

    func base64Decoded() -> String? {
        guard let data = Data(base64Encoded: self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension Array where Element: Comparable {
    mutating func insertSorted(newItem item: Element) {
        let index = insertionIndexOf(elem: item) { $0 < $1 }
        insert(item, at: index)
    }
}

extension Array {
    //https://stackoverflow.com/a/26679191/8234523
    func insertionIndexOf(elem: Element, isOrderedBefore: (Element, Element) -> Bool) -> Int {
        var lo = 0
        var hi = self.count - 1
        while lo <= hi {
            let mid = (lo + hi)/2
            if isOrderedBefore(self[mid], elem) {
                lo = mid + 1
            } else if isOrderedBefore(elem, self[mid]) {
                hi = mid - 1
            } else {
                return mid
            }
        }
        return lo
    }
}

extension Array where Element: Comparable {
    func binarySearch(elem: Element) -> Int {
        var lo = 0
        var hi = self.count - 1
        while lo <= hi {
            let mid = (lo + hi)/2
            if self[mid] < elem {
                lo = mid + 1
            } else if elem < self[mid] {
                hi = mid - 1
            } else {
                return mid
            }
        }
        return lo
    }
}

// If key does not exist in dict, create it and set it to a default value
extension Dictionary {
    subscript(key: Key, setDefault defaultValue: @autoclosure () -> Value) -> Value {
        mutating get {
            return self[key] ?? {
                let value = defaultValue()
                self[key] = value
                return value
            }()
        }
    }
}

func convertLapTimeToSeconds(time: String) -> Float {
    if time.contains("::") {
        return convertLapTimeToSeconds(time: time.components(separatedBy: "::")[0])
    }
    
    let parts = time.components(separatedBy: ":")
    if parts.count == 2 {
        return ((Float(parts[0]) ?? 0) * 60) + (Float(parts[1]) ?? 0)
    } else if parts.count == 1 {
        return Float(parts[0]) ?? 0
    } else {
        return 0
    }
}

extension FloatingPoint {
    func isNearlyEqual(to value: Self) -> Bool {
        return abs(self - value) <= .ulpOfOne
    }
}

extension SCNVector3 {
    static func !=(lhs: SCNVector3, rhs: SCNVector3) -> Bool {
        if lhs.x == rhs.x {
            if lhs.y == rhs.y {
                if lhs.z == rhs.z {
                    return false
                }
            }
        }
        return true
    }
    
    static func ==(lhs: SCNVector3, rhs: SCNVector3) -> Bool {
        return !(lhs != rhs)
    }
}
