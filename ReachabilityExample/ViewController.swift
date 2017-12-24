//
//  ViewController.swift
//  ReachabilityExample
//
//  Created by Roma Chopovenko on 12/24/17.
//  Copyright © 2017 Roma Chopovenko. All rights reserved.
//

import UIKit
import CoreTelephony

class ViewController: UIViewController {
    
    var reachability: Reachability? = Reachability.networkReachabilityForLocalWiFi()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.observeNetworkReachability()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkReachability()
    }
    
    func observeNetworkReachability() {
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityDidChange(_:)), name: NSNotification.Name(rawValue: ReachabilityDidChangeNotificationName), object: nil)
        
        _ = reachability?.startNotifier()
    }
    
    func checkReachability() {
        
        guard let r = reachability else { return }
        if r.isReachable  {
            if r.currentReachabilityStatus == .reachableViaWWAN {
                self.printNetworkType()
            } else {
                print("WIFi")
            }
            view.backgroundColor = .green
        } else {
            view.backgroundColor = .red
        }
    }
    
    @objc func reachabilityDidChange(_ notification: Notification) {
        checkReachability()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        reachability?.stopNotifier()
    }
    
    func printNetworkType() {
        let errorString: String = "Error: No Radio Access Technology Detected"
        let networkInfo = CTTelephonyNetworkInfo()
        guard let networkString = networkInfo.currentRadioAccessTechnology else {
            print(errorString)
            return
        }
        let tecnology = RadioAccessTechnology(rawValue: networkString)
        print(tecnology?.description ?? errorString)
    }

}

