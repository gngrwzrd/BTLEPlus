//
//  BTLEPlusSerialServiceProtocolMessage-JazzyExclude.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/9/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

/// The type to use for protocol message type.
typealias BTLEPlusSerialServiceProtocolMessageType_Type = UInt8

/// The type to use for packet counting.
typealias BTLEPlusSerialServicePacketCounter_Type = UInt8

/// The default max packet counter before it loops to zero.
let BTLEPlusSerialServiceMaxPacketCounter:BTLEPlusSerialServicePacketCounter_Type = 128