//
//  BLEPlusRequest.swift
//  BLEPlus
//
//  Created by Aaron Smith on 9/4/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

/// BLEPlusRequest is the class you send with BLEPlusRequestResponseController.
/// It requires a requestType and responseType which are used to map a request
/// to it's matching response when it's received.
@objc public class BLEPlusRequest : BLEPlusSerialServiceMessage {
	
	/// The request type.
	var requestType:BLEPlusRequestResponseMessageType_Type = 0
	
	/// The response type.
	var responseType:BLEPlusRequestResponseMessageType_Type = 0
	
	/**
	Create a new BLEPlusRequest.
	
	The requestType and responseType should be a uniquely identifiable integer
	that you can map to known requests and responses.
	
	The request type and response type can optionally be different. This is useful
	if you can have different responses to a request type.
	
	- parameter requestType:	The message type for this request.
	- parameter responseType:	The message type for a response to the request.
	
	- returns: BLEPlusRequest
	*/
	public init(requestType:BLEPlusRequestResponseMessageType_Type, responseType:BLEPlusRequestResponseMessageType_Type) {
		self.messageType = requestType
		self.requestType = requestType
		self.responseType = responseType
	}
	
}