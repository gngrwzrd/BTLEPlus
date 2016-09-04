//
//  BLEPlusSerialServiceMessage.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/28/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

/// BLEPlusSerialServiceMessage is the base class for sending user defined
/// messages over the BLEPlus Serial Service.
///
/// The type property is automatically encoded for you in the transfer,
/// on the peripheral or central side when you get a message callback you
/// can inspect the type to figure out what message it is.
@objc public class BLEPlusSerialServiceMessage : NSObject {
	
	/// A custom type you can use to indicate which type of user message is
	/// being transfered.
	public var messageType:BLEPlusSerialServiceMessageType_Type = 0
	
	/// A message id for tracking request / response lifecycle.
	public var messageId:BLEPLusSerialServiceMessageIdType = 0
	
	/// Data to send.
	public var data:NSData?
	
	/// A file to send.
	public var fileURL:NSURL?
	
	/// internal packet provider that the serial service controller uses.
	var provider:BLEPlusSerialServicePacketProvider?
	
	/**
	Init with data to send.
	
	- parameter withType: BLEPlusSerialServiceWrapperUserType
	- parameter data:     NSData
	
	- returns: BLEPlusSerialServiceMessage
	*/
	public init?(withType:BLEPlusSerialServiceMessageType_Type, messageId:BLEPLusSerialServiceMessageIdType, data:NSData) {
		guard data.length > 0 else {
			return nil
		}
		self.data = data
		self.messageType = withType
		self.messageId = messageId
		if let provider = BLEPlusSerialServicePacketProvider(withData: data) {
			self.provider = provider
			return
		}
		return nil
	}
	
	/**
	Init with a file URL to send.
	
	- parameter withType:     BLEPlusSerialServiceWrappedUserType
	- parameter withFileURL:  NSURL
	
	- returns: BLEPlusSerialServiceMessage
	*/
	public init?(withType:BLEPlusSerialServiceMessageType_Type, messageId:BLEPLusSerialServiceMessageIdType, fileURL:NSURL) {
		guard withType > 0 else {
			return nil
		}
		guard let path = fileURL.path else {
			return nil
		}
		guard NSFileManager.defaultManager().fileExistsAtPath(path) else {
			return nil
		}
		self.fileURL = fileURL
		self.messageType = withType
		self.messageId = messageId
		if let provider = BLEPlusSerialServicePacketProvider(withFileURLForReading: fileURL) {
			self.provider = provider
			return
		}
		return nil
	}
}