//
//  BLEPlusHeartRateService.swift
//  BLEPlus
//
//  Created by Aaron Smith on 9/7/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation
import CoreBluetooth

//https://www.bluetooth.com/specifications/gatt/viewer?attributeXmlFile=org.bluetooth.service.heart_rate.xml
@objc public class BLEPlusHeartRateService : BLEPlusServiceSpec {
	
	public static let assignedNumber:UInt32 = 0x180D
	public static var UUID:String = "180D"
	public static var UUIDCB:CBUUID = CBUUID(string: UUID)
	
}

@objc public class BLEPlusHeartRateMeasurementCharacteristic : BLEPlusCharacteristicSpec {
	
	public static let assignedNumber:UInt32 = 0x2A37
	public static let UUID:String = "2A37"
	public static let UUIDCB:CBUUID = CBUUID(string: UUID)
	
}

@objc public class BLEPlusHeartRateBodySensorLocationCharacteristic : BLEPlusCharacteristicSpec {
	
	public static let assignedNumber:UInt32 = 0x2A38
	public static let UUID:String = "2A38"
	public static let UUIDCB:CBUUID =  CBUUID(string: UUID)
	
}

@objc public class BLEPlusHeartRateControlPointCharacteristic : BLEPlusCharacteristicSpec {
	
	public static let assignedNumber:UInt32 = 0x2A39
	public static let UUID:String = "2A39"
	public static let UUIDCB:CBUUID = CBUUID(string: UUID)
	
}
