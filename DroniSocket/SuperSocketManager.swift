//
//  SuperSocketManager.swift
//  DroniSocket
//
//  Created by Gweltaz calori on 09/02/2019.
//  Copyright © 2019 Gweltaz calori. All rights reserved.
//

import Foundation
import SocketIO

class SuperSocketManager {
    let manager = SocketManager(socketURL: URL(string: "http://192.168.2.25:3000")!, config: [.log(false), .compress])
    
    func connect() {
        manager.defaultSocket.connect()
    }
    
    func on(eventName:String, callback : @escaping (_ data:Any) -> Void) {
        manager.defaultSocket.on(eventName) { (dataArray, ack) in
            callback(dataArray)
        }
        
    }
    
    func emit(eventName: String,data:Any) {
        manager.defaultSocket.emit(eventName, with: [data])
    }
}
