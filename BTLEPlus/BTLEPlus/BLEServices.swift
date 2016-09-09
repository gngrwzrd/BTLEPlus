//
//  BLEServices.swift
//  IntelDeviceKitMacSandbox
//
//  Created by Aaron Smith on 8/13/16.
//  Copyright © 2016 Aaron Smith. All rights reserved.
//

import Foundation
import CoreBluetooth

//Services available in bluetooth BLE spec
//https://developer.bluetooth.org/gatt/services/Pages/ServicesHome.aspx

@objc public class BLEHeartrate : NSObject {
	@objc public static let specification:String = "org.bluetooth.service.heart_rate"
	@objc public static let assignedNumber = 0x180D
	@objc public static let scanCBUUID:CBUUID = CBUUID(string: "180D")
	@objc public static let assignedNumberCBUUID:CBUUID = CBUUID(string: "180D")
}
