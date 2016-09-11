//
//  BTLEPlusSerialServiceMessage.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 8/28/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

/**
The BTLEPlusSerialServiceMessage class is the base class for all user defined
messages that are sent over the serial service protocol. You pass instances of
this to _BTLEPlusSerialServiceController.send()_.
*/
@objc public class BTLEPlusSerialServiceMessage : NSObject {
	
	/// A user defined type.
	public var messageType:BTLEPlusSerialServiceMessageType_Type = 0
	
	/// A user defined message id for tracking the message when it's sent
	/// from one peer to the other.
	public var messageId:BTLEPlusSerialServiceMessageId_Type = 0
	
	/// User defined data to send.
	public var data:NSData?
	
	/// User defined file to send.
	public var fileURL:NSURL?
	
	/// internal packet provider that the serial service controller uses.
	var provider:BTLEPlusSerialServicePacketProvider?
	
	/**
	Initialize a BTLEPlusSerialServiceMessage with it's message type, message id, and data.
	
	- parameter withMessageType: User defined message type.
	- parameter messageId: User defined message id for tracking messages.
	- parameter data: User defined data.
	
	- returns: BTLEPlusSerialServiceMessage
	*/
	public init?(withMessageType:BTLEPlusSerialServiceMessageType_Type, messageId:BTLEPlusSerialServiceMessageId_Type, data:NSData) {
		guard data.length > 0 else {
			return nil
		}
		self.data = data
		self.messageType = withMessageType
		self.messageId = messageId
		if let provider = BTLEPlusSerialServicePacketProvider(withData: data) {
			self.provider = provider
			return
		}
		return nil
	}
	
	/**
	Init with a file URL to send.
	
	- parameter withType:     BTLEPlusSerialServiceMessageId_Type
	- parameter withFileURL:  NSURL
	
	- returns: BTLEPlusSerialServiceMessage
	*/
	public init?(withMessageType:BTLEPlusSerialServiceMessageType_Type, messageId:BTLEPlusSerialServiceMessageId_Type, fileURL:NSURL) {
		guard withMessageType > 0 else {
			return nil
		}
		guard let path = fileURL.path else {
			return nil
		}
		guard NSFileManager.defaultManager().fileExistsAtPath(path) else {
			return nil
		}
		self.fileURL = fileURL
		self.messageType = withMessageType
		self.messageId = messageId
		if let provider = BTLEPlusSerialServicePacketProvider(withFileURLForReading: fileURL) {
			self.provider = provider
			return
		}
		return nil
	}
}