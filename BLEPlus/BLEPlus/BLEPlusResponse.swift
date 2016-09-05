//
//  BLEPlusResponse.swift
//  BLEPlus
//
//  Created by Aaron Smith on 9/4/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

/// BLEPlusResponse is the class you receive as a response to sending a
/// request with BLEPlusRequestResponse.
@objc public class BLEPlusResponse : BLEPlusSerialServiceMessage {
	
	/// Response type.
	var responseType:BLEPlusRequestResponseMessageType_Type = 0
	
	/**
	Create a new BLEPlusResponse.
	
	The response type should be something uniquely identifiable.
	
	- parameter responseType:	BLEPlusRequestResponseMessageType_Type
	
	- returns: BLEPlusResponse
	*/
	public init(responseType:UInt8) {
		self.messageType = responseType
		self.responseType = responseType
	}
	
}
