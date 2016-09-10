//
//  BLEPlusSerialServiceProtocolMessage-JazzyExclude.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/9/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

/// The type to use for protocol message type.
typealias BLEPlusSerialServiceProtocolMessageType_Type = UInt8

/// The type to use for packet counting.
typealias BLEPlusSerialServicePacketCountType = UInt8

/// This is the maximum transmission unit minus any header data.
let BLEPlusSerialServiceRealMTU:UInt16 = BLEPlusSerialServiceDefaultMTU - UInt16(BLEPlusSerialServicePacketProvider.headerSize + BLEPlusSerialServiceProtocolMessage.headerSize)

/// The default max packet counter before it loops to zero.
let BLEPlusSerialServiceMaxPacketCounter:BLEPlusSerialServicePacketCountType = 128