//
//  Reachability.swift
//  ReachabilityExample
//
//  Created by Roma Chopovenko on 12/24/17.
//  Copyright © 2017 Roma Chopovenko. All rights reserved.
//

import Foundation
import SystemConfiguration
import CoreTelephony

let ReachabilityDidChangeNotificationName = "ReachabilityDidChangeNotification"

enum ReachabilityStatus {
    case notReachable
    case reachableViaWiFi
    case reachableViaWWAN
}

import CoreTelephony

enum RadioAccessTechnology: String {
    case cdma = "CTRadioAccessTechnologyCDMA1x"
    case edge = "CTRadioAccessTechnologyEdge"
    case gprs = "CTRadioAccessTechnologyGPRS"
    case hrpd = "CTRadioAccessTechnologyeHRPD"
    case hsdpa = "CTRadioAccessTechnologyHSDPA"
    case hsupa = "CTRadioAccessTechnologyHSUPA"
    case lte = "CTRadioAccessTechnologyLTE"
    case rev0 = "CTRadioAccessTechnologyCDMAEVDORev0"
    case revA = "CTRadioAccessTechnologyCDMAEVDORevA"
    case revB = "CTRadioAccessTechnologyCDMAEVDORevB"
    case wcdma = "CTRadioAccessTechnologyWCDMA"
    
    var description: String {
        switch self {
        case .gprs, .edge, .cdma:
            return "2G"
        case .lte:
            return "4G"
        default:
            return "3G \(rawValue)"
        }
    }
}

class Reachability: NSObject {
    
    private var networkReachability: SCNetworkReachability?
    private var notifying: Bool = false
    
    private var flags: SCNetworkReachabilityFlags {
        
        var flags = SCNetworkReachabilityFlags(rawValue: 0)
        
        if let reachability = networkReachability, withUnsafeMutablePointer(to: &flags, { SCNetworkReachabilityGetFlags(reachability, UnsafeMutablePointer($0)) }) == true {
            return flags
        } else {
            return []
        }
    }
    
    var currentReachabilityStatus: ReachabilityStatus {
        
        if flags.contains(.reachable) == false {
            // The target host is not reachable.
            return .notReachable
        } else if flags.contains(.isWWAN) == true {
            // WWAN connections are OK if the calling application is using the CFNetwork APIs.
            return .reachableViaWWAN
        } else if flags.contains(.connectionRequired) == false {
            // If the target host is reachable and no connection is required then we'll assume that you're on Wi-Fi...
            return .reachableViaWiFi
        } else if (flags.contains(.connectionOnDemand) == true || flags.contains(.connectionOnTraffic) == true) && flags.contains(.interventionRequired) == false {
            // The connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs and no [user] intervention is needed
            return .reachableViaWiFi
        } else {
            return .notReachable
        }
    }
    
    var isReachable: Bool {
        switch currentReachabilityStatus {
        case .notReachable:
            return false
        case .reachableViaWiFi, .reachableViaWWAN:
            return true
        }
    }
    
    init?(hostName: String) {
        guard let name = (hostName as NSString).utf8String else { return nil }
        networkReachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, name)
        super.init()
        if networkReachability == nil {
            return nil
        }
    }
    
    init?(hostAddress: sockaddr_in) {
        var address = hostAddress
        
        guard let defaultRouteReachability = withUnsafePointer(to: &address, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, $0)
            }
        }) else {
            return nil
        }
        
        networkReachability = defaultRouteReachability
        
        super.init()
        if networkReachability == nil {
            return nil
        }
    }
    
    static func networkReachabilityForInternetConnection() -> Reachability? {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        return Reachability(hostAddress: zeroAddress)
    }
    
    static func networkReachabilityForLocalWiFi() -> Reachability? {
        var localWifiAddress = sockaddr_in()
        localWifiAddress.sin_len = UInt8(MemoryLayout.size(ofValue: localWifiAddress))
        localWifiAddress.sin_family = sa_family_t(AF_INET)
        // IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0 (0xA9FE0000).
        localWifiAddress.sin_addr.s_addr = 0xA9FE0000
        
        return Reachability(hostAddress: localWifiAddress)
    }
    
    func startNotifier() -> Bool {
        
        guard notifying == false else { return false }
        
        var context = SCNetworkReachabilityContext()
        context.info = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        
        guard let reachability = networkReachability, SCNetworkReachabilitySetCallback(reachability, { (target: SCNetworkReachability, flags: SCNetworkReachabilityFlags, info: UnsafeMutableRawPointer?) in
            if let currentInfo = info {
                let infoObject = Unmanaged<AnyObject>.fromOpaque(currentInfo).takeUnretainedValue()
                if infoObject is Reachability {
                    let networkReachability = infoObject as! Reachability
                    NotificationCenter.default.post(name: Notification.Name(rawValue: ReachabilityDidChangeNotificationName), object: networkReachability)
                }
            }
        }, &context) == true else { return false }
        
        guard SCNetworkReachabilityScheduleWithRunLoop(reachability, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue) == true else { return false }
        
        notifying = true
        return notifying
    }
    
    func stopNotifier() {
        if let reachability = networkReachability, notifying == true {
            SCNetworkReachabilityUnscheduleFromRunLoop(reachability, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode as! CFString)
            notifying = false
        }
    }
    
    deinit {
        stopNotifier()
    }
    
    
}
