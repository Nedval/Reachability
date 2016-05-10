//
//  Reachability.swift
//
//  Created by Jrting Shiau on 5/10/16.
//
//

import Foundation
import SystemConfiguration

enum NetworkStatus: Int {

    case NotReachable = 0

    case ReachableViaWiFi
    
    case ReachableViaWWAN
    
}

let kReachabilityChangedNotification = "kNetworkReachabilityChangedNotification"

// MARK: - Supporting functions

let kShouldPrintReachabilityFlags = true

private func PrintReachabilityFlags(flags: SCNetworkReachabilityFlags, comment: String) {
    
    if kShouldPrintReachabilityFlags {
        
        print(
            String(
                format: "Reachability Flag Status: %@%@ %@%@%@%@%@%@%@ %@\n",
                flags.contains(.IsWWAN)                 ? "W" : "-",
                flags.contains(.Reachable)              ? "R" : "-",
                flags.contains(.TransientConnection)    ? "t" : "-",
                flags.contains(.ConnectionRequired)     ? "c" : "-",
                flags.contains(.ConnectionOnTraffic)    ? "C" : "-",
                flags.contains(.InterventionRequired)   ? "i" : "-",
                flags.contains(.ConnectionOnDemand)     ? "D" : "-",
                flags.contains(.IsLocalAddress)         ? "l" : "-",
                flags.contains(.IsDirect)               ? "d" : "-",
                comment
            )
        )
        
    }

}

private func ReachabilityCallback(target: SCNetworkReachabilityRef, flags: SCNetworkReachabilityFlags, info: UnsafeMutablePointer<Void>) {
    
    assert(info != nil, "info was NULL in ReachabilityCallback")
    
    assert(unsafeBitCast(info, NSObject.self) is Reachability, "info was wrong class in ReachabilityCallback")
    
    let note_object = unsafeBitCast(info, Reachability.self)
    
    // Post a notification to notify the client that the network reachability changed.
    
    NSNotificationCenter.defaultCenter().postNotificationName(kReachabilityChangedNotification, object: note_object)
    
}

// MARK: - Reachability implementation

class Reachability: NSObject {

    private var _reachability_ref: SCNetworkReachabilityRef?

    /*!
     * Use to check the reachability of a given host name.
     */
    
    convenience init?(reachabilityWithHostName host_name: NSString) {

        guard let reachability = SCNetworkReachabilityCreateWithName(nil, host_name.UTF8String) else {
        
            return nil

        }

        self.init()

        _reachability_ref = reachability

    }

    /*!
     * Use to check the reachability of a given IP address.
     */

    convenience init?(reachabilityWithAddress host_address: UnsafePointer<sockaddr>) {
        
        guard let reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, host_address) else {

            return nil

        }

        self.init()

        _reachability_ref = reachability
    
    }

    /*!
     * Checks whether the default route is available. Should be used by applications that do not connect to a particular host.
     */

    class func reachabilityForInternetConnection() -> Reachability? {
        
        var zero_address = sockaddr_in()
        
        bzero(&zero_address, sizeofValue(zero_address))
        
        zero_address.sin_len = UInt8(sizeofValue(zero_address))
        
        zero_address.sin_family = sa_family_t(AF_INET)
        
        return withUnsafeMutablePointer(&zero_address) {
            
            Reachability(reachabilityWithAddress: UnsafeMutablePointer($0))
            
        }
        
    }
    
    // MARK: - Start and stop notifier

    /*!
     * Start listening for reachability notifications on the current run loop.
     */

    func startNotifier() -> Bool {
        
        var return_value: Bool = false
        
        var context = SCNetworkReachabilityContext(
            version: 0,
            info: UnsafeMutablePointer(unsafeAddressOf(self)),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        if SCNetworkReachabilitySetCallback(_reachability_ref!, ReachabilityCallback, &context) {
            
            if SCNetworkReachabilityScheduleWithRunLoop(_reachability_ref!, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode) {
                
                return_value = true
            
            }
            
        }
        
        return return_value
    
    }
    
    
    func stopNotifier() {
        
        if let reachability_ref = _reachability_ref {
        
            SCNetworkReachabilityUnscheduleFromRunLoop(reachability_ref, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode)
        
        }
        
    }
    
    deinit {
        
        self.stopNotifier()
        
    }
    
    // MARK: - Network Flag Handling

    func networkStatusForFlags(flags: SCNetworkReachabilityFlags) -> NetworkStatus {
        
        PrintReachabilityFlags(flags, comment: "networkStatusForFlags")
        
        if !flags.contains(.Reachable) {
            
            // The target host is not reachable.
            
            return .NotReachable
        
        }
        
        var return_value = NetworkStatus.NotReachable
        
        if !flags.contains(.ConnectionRequired) {
            
            /*
             If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
             */
            
            return_value = .ReachableViaWiFi
        
        }
        
        if flags.contains(.ConnectionOnDemand) || flags.contains(.ConnectionOnTraffic) {
            
            /*
             ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
             */
            
            if !flags.contains(.InterventionRequired) {
            
                /*
                 ... and no [user] intervention is needed...
                 */
                
                return_value = .ReachableViaWiFi
            
            }
        
        }
        
        if flags.contains(.IsWWAN) {
            
            /*
             ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
             */
            
            return_value = .ReachableViaWWAN
        
        }
        
        return return_value
    
    }

    /*!
     * WWAN may be available, but not active until a connection has been established. WiFi may require a connection for VPN on Demand.
     */

    func connectionRequired() -> Bool {

        assert(_reachability_ref != nil, "connectionRequired called with NULL reachabilityRef")

        var flags = SCNetworkReachabilityFlags()

        if SCNetworkReachabilityGetFlags(_reachability_ref!, &flags) {

            return flags.contains(.ConnectionRequired)

        }

        return false
    }

    func currentReachabilityStatus() -> NetworkStatus {

        assert(_reachability_ref != nil, "currentNetworkStatus called with NULL SCNetworkReachabilityRef")

        var return_value: NetworkStatus = .NotReachable

        var flags = SCNetworkReachabilityFlags()

        if SCNetworkReachabilityGetFlags(_reachability_ref!, &flags) {

            return_value = self.networkStatusForFlags(flags)

        }

        return return_value

    }
    
}