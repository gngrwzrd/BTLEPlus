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
@objc public class BLEPlusRequestResponseController : BLEPlusSerialServiceController {
	
	/// Delegate to receive callbacks.
	public var requestResponseDelegate:BLEPlusRequestResponseControllerDelegate?
	
	/// Pending requests.
	var requests:[BLEPlusRequest] = []
	
	/// A counter for message ids.
	static var messageIdCounter:BLEPlusRequestResponseMessageId_Type = 0
	
	/**
	Create a BLEPlusRequestResponseController.
	
	- parameter requestResponseDelegate:	AnyObject that implements the protocol.
	
	- returns: BLEPlusRequestController.
	*/
	public init(requestResponseDelegate:BLEPlusRequestResponseControllerDelegate, mode:BLEPlusSerialServiceControllerMode, delegateQueue:dispatch_queue_t) {
		super.init(withMode: mode, delegateQueue: delegateQueue)
		self.requestResponseDelegate = requestResponseDelegate
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
		send(request)
	}
	
	/**
	Send a response to a request.
	
	- parameter forRequest:	BLEPlusRequest - The request to respond to.
	- parameter response:	BLEPlusResponse - The response.
	*/
	public func sendResponse(forRequest:BLEPlusRequest, response:BLEPlusResponse) {
		response.messageId = forRequest.messageId
		send(response)
	}
	
	/**
	Call when you get the serialServiceController receivedMessage delegate callback.
	
	- parameter message:	BLEPlusSerialServiceMessage
	*/
	public func receivedMessage(message:BLEPlusSerialServiceMessage) {
		for request in self.requests {
			if request.messageId == message.messageId {
				let response = BLEPlusResponse(responseType: request.responseType)
				requestResponseDelegate?.requestResponseControllerReceivedResponse?(response, forRequest: request)
			}
		}
	}
	
	/**
	Call this when you get the serialServiceController sentMessage delegate callback.
	
	- parameter message:	BLEPlusSerialServiceMessage
	*/
	public func sentMessage(message:BLEPlusSerialServiceMessage) {
		//Find pending request and call delegate with it.
		for request in self.requests {
			if request.messageId == message.messageId {
				requestResponseDelegate?.requestResponseController?(self, sentRequest: request)
			}
		}
	}
	
}