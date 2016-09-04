//
//  BLEPlusSerialService.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/28/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

/// The type to use for protocol message type.
public typealias BLEPlusSerialServiceProtocolMessageType_Type = UInt8

/// The type to use for message type.
public typealias BLEPlusSerialServiceMessageType_Type = UInt8

/// The type to use for message id.
public typealias BLEPLusSerialServiceMessageIdType = UInt8

/// The type to use for window size.
public typealias BLEPlusSerialServiceWindowSizeType = UInt8

/// The type to use for maximum transmission unit.
public typealias BLEPlusSerialServiceMTUType = UInt16

/// The type to use for packet counting.
public typealias BLEPlusSerialServicePacketCountType = UInt8

/// The default maximum transmission unit. Note that messages subtract
/// their header size from this MTU value. So the actual supported payload
/// is this value - header sizes. Header sizes can be different for different
/// kinds of messages.
public let BLEPlusSerialServiceDefaultMTU:UInt16 = 128

/// This is the real payload mtu after headers are subtracted.
public let BLEPlusSerialServiceRealMTU:UInt16 = BLEPlusSerialServiceDefaultMTU - UInt16(BLEPlusSerialServicePacketProvider.headerSize + BLEPlusSerialServiceProtocolMessage.headerSize)

/// The default max window size.
public let BLEPlusSerialServiceMaxWindowSize:BLEPlusSerialServiceWindowSizeType = 32

/// The default max packet counter before it loops to zero.
public let BLEPlusSerialServiceMaxPacketCounter:BLEPlusSerialServicePacketCountType = 128

/// Extension for NSData to print the data as hex values
extension NSData {
	
	/// print data as hex values
	func bleplus_base16EncodedString(uppercase uppercase: Bool = false) -> String {
		let buffer = UnsafeBufferPointer<UInt8>(start: UnsafePointer(self.bytes),count: self.length)
		let hexFormat = uppercase ? "X" : "x"
		let formatString = "0x%02\(hexFormat) "
		//let asciiFormat = "%c "
		let bytesAsHexStrings = buffer.map {
			String(format: formatString, $0)
		}
		return bytesAsHexStrings.joinWithSeparator("")
	}
	
}
