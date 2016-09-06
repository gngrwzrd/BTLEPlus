//
//  BLEPlusRequestResponseController.swift
//  BLEPlus
//
//  Created by Aaron Smith on 9/5/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

class Request {
	var responseType:BLEPLusSerialServiceMessageId_Type = 0
	var message:BLEPlusSerialServiceMessage!
}

@objc public protocol BLEPlusRequestResponseControllerDelegate {
	optional func requestResponseController(controller:BLEPlusRequestResponseController, receivedRequest:BLEPlusSerialServiceMessage)
	optional func requestResponseController(controller:BLEPlusRequestResponseController, receivedResponse:BLEPlusSerialServiceMessage, forRequest:BLEPlusSerialServiceMessage)
}

public class BLEPlusRequestResponseController : NSObject {
	
	var requests:[Request] = []
	public var delegate:BLEPlusRequestResponseControllerDelegate? = nil
	public var messageIdCounter:BLEPlusSerialServiceMessageType_Type = 0
	
	override public init() {
		super.init()
	}
	
	public func trackMessage(message:BLEPlusSerialServiceMessage, waitForResponseType:BLEPLusSerialServiceMessageId_Type = 0) {
		if message.messageId < 1 {
			return
		}
		let request = Request()
		request.message = message
		request.responseType = waitForResponseType
		self.requests.append(request)
	}
	
	public func receivedMessage(message:BLEPlusSerialServiceMessage) {
		for request in self.requests {
			if message.messageType == request.responseType && request.message.messageId == message.messageId {
				self.delegate?.requestResponseController?(self, receivedResponse: message, forRequest:request.message)
				self.requests = self.requests.filter({$0.message.messageId != message.messageId && $0.message.messageType != message.messageType})
				return
			}
		}
		if message.messageType > 0 && message.messageId > 0 {
			self.delegate?.requestResponseController?(self, receivedRequest: message)
		}
	}
}
