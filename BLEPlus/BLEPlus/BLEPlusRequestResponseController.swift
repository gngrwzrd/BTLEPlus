//
//  BLEPlusRequestResponseController.swift
//  BLEPlus
//
//  Created by Aaron Smith on 9/4/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

/// The type for request/response message types.
public typealias BLEPlusRequestResponseMessageType_Type = BLEPlusSerialServiceMessageType_Type

/// The type for request/response message id identifiers.
public typealias BLEPlusRequestResponseMessageId_Type = BLEPLusSerialServiceMessageId_Type

/// The BLEPlusRequestResponseControllerDelegate is the protocol you implement
/// to receive callbacks from a BLEPlusRequestResponseController.
@objc public protocol BLEPlusRequestResponseControllerDelegate {
	
	/**
	This is required in order to send data.
	
	- parameter controller:	BLEPlusRequestResponseController
	- parameter data:			NSData
	*/
	func requestResponseController(controller:BLEPlusRequestResponseController, wantsToSendData data:NSData)
	
	/**
	Called when a request has been sent.
	
	- parameter controller:	 BLEPlusRequestResponseController
	- parameter sentRequest: BLEPlusRequest
	*/
	optional func requestResponseController(controller:BLEPlusRequestResponseController, sentRequest:BLEPlusRequest)
	
	/**
	Called when a response has been received for it's matching request.
	
	- parameter response:   BLEPlusResponse
	- parameter forRequest: BLEPlusRequest
	*/
	optional func requestResponseControllerReceivedResponse(response:BLEPlusResponse, forRequest:BLEPlusRequest)
}

/// The BLEPlusRequestResponseController handles maps messages into requests and responses.
/// Internally this uses a BLEPlusSerialServiceController which handles all of the protocol management
/// for you. Responses may come back to you out of the order the requests were sent in.
@objc public class BLEPlusRequestResponseController : NSObject, BLEPlusSerialServiceControllerDelegate {
	
	/// Delegate to receive callbacks.
	public var delegate:BLEPlusRequestResponseControllerDelegate?
	
	/// A serial controller that does the lifing.
	public var serialController:BLEPlusSerialServiceController?
	
	/// Pending requests.
	var requests:[BLEPlusRequest] = []
	
	/// A counter for message ids.
	class var messageIdCounter:BLEPlusRequestResponseMessageId_Type = 0
	
	/**
	Init a new BLEPlusRequestResponseController.
	
	- parameter mode:	The mode to operate as.
	
	- returns: BLEPlusRequestResponseController.
	*/
	public init(mode:BLEPlusSerialServiceControllerMode) {
		self.serialController = BLEPlusSerialServiceController(mode)
		self.serialController?.delegate = self
	}
	
	/**
	Send a request, and asynchrounously await a response via the delegate.
	
	- parameter request:	BLEPlusRequest.
	*/
	public func sendRequest(request:BLEPlusRequest) {
		var messageId = BLEPlusRequestResponseController.messageIdCounter
		request.messageId = messageId
		self.requests.append(request)
		messageId = messageId + 1
		if messageId == BLEPlusSerialServiceMaxMessageId {
			messageId = 0
		}
		BLEPlusRequestResponseController.messageIdCounter = messageId
		self.serialController?.send(request)
	}
	
	/**
	Send a response to a request.
	
	- parameter forRequest:	BLEPlusRequest - The request to respond to.
	- parameter response:	BLEPlusResponse - The response.
	*/
	public func sendResponse(forRequest:BLEPlusRequest, response:BLEPlusResponse) {
		response.messageId = forRequest.messageId
		self.serialController?.send(response)
	}
	
	/**
	You are required to call this when you receive raw data.
	
	- parameter data:	NSData
	*/
	public func receivedData(data:NSData) {
		self.serialController?.receivedData(data)
	}
	
	/// Delegate implementation for serial service controller
	func serialServiceController(controller: BLEPlusSerialServiceController, wantsToSendData data: NSData) {
		self.delegate?.requestResponseController(self, wantsToSendData: data)
	}
	
	/// Serial service sent a complete message, lookup pending request and send to delegate as being sent.
	func serialServiceController(controller: BLEPlusSerialServiceController, sentMessage message: BLEPlusSerialServiceMessage) {
		//Find pending request and call delegate with it.
		for request in self.requests {
			if request.messageId == message.messageId {
				delegate?.requestResponseController(self, sentRequest: request)
			}
		}
	}
	
	/// Received a complete message, the message id is used to lookup the request and pass a response to the delegate.
	func serialServiceController(controller: BLEPlusSerialServiceController, receivedMessage message: BLEPlusSerialServiceMessage) {
		//if this is a response type
		//look up requests and find matching messageId
		for request in self.requests {
			if request.messageId == message.messageId {
				let response = BLEPlusResponse(responseType: request.responseType)
				delegate?.requestResponseControllerReceivedResponse(message, forRequest: response)
			}
		}
	}
	
}