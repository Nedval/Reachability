//
//  ViewController.swift
//  ReachabilityDemo
//
//  Created by Jrting on 5/10/16.
//  Copyright © 2016 Modern Wizard Studio. All rights reserved.
//

import UIKit
import Whisper

class ViewController: UIViewController {

    private let _internet_reachability = Reachability.reachabilityForInternetConnection()

    override func viewDidLoad() {

        super.viewDidLoad()

        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: #selector(self.reachabilityChange),
            name: kReachabilityChangedNotification,
            object: nil
        )

        _internet_reachability?.startNotifier()

    }

    func reachabilityChange(note: NSNotification) {

        if let reachability = note.object as? Reachability {

            switch reachability.currentReachabilityStatus() {

            case .NotReachable:

                let murmur = Murmur(
                    title: "\(reachability.currentReachabilityStatus())",
                    backgroundColor: UIColor.redColor(),
                    titleColor: UIColor.whiteColor()
                )

                Whistle(murmur, action: .Present)

            default:

                let murmur = Murmur(
                    title: "\(reachability.currentReachabilityStatus())",
                    backgroundColor: UIColor.greenColor(),
                    titleColor: UIColor.whiteColor()
                )
                
                Whistle(murmur)
                
            }
            
        }
        
    }
    
}