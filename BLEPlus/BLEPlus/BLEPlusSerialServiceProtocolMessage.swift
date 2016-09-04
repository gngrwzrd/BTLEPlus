//
//  BLEPlusSerialServiceControlMessage.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/23/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

/**
Control message types.

- None:					None.
- PeerInfo:				Peer transfer information.
- Ack:					Acknowledge.
- NewMessage:			Client or server is requesting to send a new message.
- NewFileMessage:		Client or server is requesting to send a new file message.
- EndPart:				End the current window.
- EndMessage:			End the current message.
- Resend:				Resend the current window.
- Data:					Data message.
- Abort:					Abort the current state and reset. Allow the central to start over.
*/
public enum BLEPlusSerialServiceProtocolMessageType : BLEPlusSerialServiceProtocolMessageType_Type {
	case None = 0
	case PeerInfo = 1
	case Ack = 2
	case NewMessage = 3
	case NewFileMessage = 4
	case EndPart = 5
	case EndMessage = 6
	case Data = 7
	case Resend = 8
	case Abort = 9
}

/// BLEPlusSerialServiceMessage is used over the control channel
/// to communicate what's happening on the transfer channel.
public class BLEPlusSerialServiceProtocolMessage : NSObject {
	
	/// The size of the header for a BLEPlusSerialServiceMessage.
	/// Default value is 1 byte for the message type.
	public static var headerSize:UInt8 = 1
	
	/// Message type
	public var protocolType:BLEPlusSerialServiceProtocolMessageType = .None
	
	/// A custom user message type.
	public var messageType:UInt8 = 0
	
	/// A custom user message id.
	public var messageId:BLEPLusSerialServiceMessageIdType = 0
	
	/// Raw message data.
	public var data:NSData? = nil
	
	/// For data messages, this is the packet data stripped of the type header.
	public var packetPayload:NSData?
	
	/// Maximum Transmission Unit
	public var mtu:BLEPlusSerialServiceMTUType = 0
	
	/// Window size. Max window size is 64.
	public var windowSize:BLEPlusSerialServiceWindowSizeType {
		get {
			return _windowSize
		} set(new) {
			if new > BLEPlusSerialServiceMaxWindowSize || new < 0 {
				_windowSize = BLEPlusSerialServiceMaxWindowSize
			} else {
				_windowSize = new
			}
		}
	}
	private var _windowSize:BLEPlusSerialServiceWindowSizeType = BLEPlusSerialServiceMaxWindowSize
	
	/// The packet to resend data from.
	public var resendFromPacket:BLEPlusSerialServicePacketCountType = 0
	
	/// The expected message size.
	public var messageSize:UInt64 = 0
	
	/**
	Initialize with the control type. This is only used when there is no other
	data required as part of the message
	
	- parameter withType: The control message type.
	
	- returns: BLEPlusSerialServiceMessage
	*/
	public init(withType:BLEPlusSerialServiceProtocolMessageType) {
		super.init()
		self.protocolType = withType
		let data = NSMutableData()
		data.appendBytes(&protocolType, length: sizeof(protocolType.rawValue.dynamicType))
		self.data = data
	}
	
	/**
	Initialize a control message with raw NSData. The data is expected to be
	in the protocol message format.
	
	- parameter withData:  Protocol format data.
	
	- returns: BLEPlusSerialServiceMessage
	*/
	public init(withData:NSData?) {
		super.init()
		guard let data = withData else {
			return
		}
		self.data = withData
		data.getBytes(&protocolType, range: NSRange.init(location:0, length: sizeof(protocolType.rawValue.dynamicType)))
		if isValidControlMessage() {
			
			if protocolType == .PeerInfo {
				var noMTU:UInt16 = 0
				data.getBytes(&noMTU, range: NSRange.init(location: sizeof(protocolType.rawValue.dynamicType), length: sizeof(mtu.dynamicType)))
				self.mtu = CFSwapInt16BigToHost(noMTU)
				data.getBytes(&windowSize, range: NSRange.init(location: sizeof(protocolType.rawValue.dynamicType) + sizeof(mtu.dynamicType), length: sizeof(windowSize.dynamicType)))
			}
			
			if protocolType == .Resend {
				data.getBytes(&resendFromPacket, range: NSRange.init(location: sizeof(protocolType.rawValue.dynamicType), length: sizeof(resendFromPacket.dynamicType)))
			}
			
			if protocolType == .NewMessage || protocolType == .NewFileMessage {
				data.getBytes(&messageType, range: NSRange.init(location: sizeof(protocolType.rawValue.dynamicType), length: sizeof(messageType.dynamicType)))
				data.getBytes(&messageId, range: NSRange.init(location: sizeof(protocolType.rawValue.dynamicType) + sizeof(messageType.dynamicType), length: sizeof(messageId.self.dynamicType)))
				var noMessageSize:UInt64 = 0
				data.getBytes(&noMessageSize, range: NSRange.init(location: sizeof(protocolType.rawValue.dynamicType) + sizeof(messageType.dynamicType) + sizeof(messageId.self.dynamicType), length: sizeof(messageSize.dynamicType)))
				messageSize = CFSwapInt64BigToHost(noMessageSize)
			}
			
			if protocolType == .EndMessage {
				data.getBytes(&windowSize, range: NSRange.init(location: sizeof(protocolType.rawValue.dynamicType), length: sizeof(windowSize.dynamicType)))
			}
			
			if protocolType == .Data {
				packetPayload = data.subdataWithRange(NSRange.init(location: 1, length: data.length-1))
			}
		}
	}
	
	/**
	Create a peer info message with MTU and window size.
	
	- parameter peerInfoMessageWithMTU:	Maximum transmission unit.
	- parameter windowSize:							Window size. Max is 64
	
	- returns: BLEPlusSerialServiceMessage
	*/
	public init(peerInfoMessageWithMTU:BLEPlusSerialServiceMTUType, windowSize:BLEPlusSerialServiceWindowSizeType) {
		super.init()
		protocolType = .PeerInfo
		mtu = peerInfoMessageWithMTU
		self.windowSize = windowSize
		let data = NSMutableData()
		var noMTU = CFSwapInt16HostToBig(mtu)
		data.appendBytes(&protocolType, length: sizeof(protocolType.rawValue.dynamicType))
		data.appendBytes(&noMTU, length: sizeof(mtu.self.dynamicType))
		data.appendBytes(&self.windowSize, length: sizeof(windowSize.self.dynamicType))
		self.data = data
	}
	
	/**
	Create a resend message with start from packet.
	
	- parameter resendMessageWithStartFromPacket:	The packet to start from.
	
	- returns: BLEPlusSerialServiceMessage
	*/
	public init(resendMessageWithStartFromPacket:BLEPlusSerialServicePacketCountType) {
		super.init()
		protocolType = .Resend
		resendFromPacket = resendMessageWithStartFromPacket
		let data = NSMutableData()
		data.appendBytes(&protocolType, length: sizeof(protocolType.rawValue.dynamicType))
		data.appendBytes(&resendFromPacket, length: sizeof(resendFromPacket.dynamicType))
		self.data = data
	}
	
	/**
	Creates an end control message with window size.
	
	- parameter endMessageWithWindowSize:	The window size for the last window of the message.
	
	- returns: BLEPlusSerialServiceMessage
	*/
	public init(endMessageWithWindowSize:BLEPlusSerialServiceWindowSizeType) {
		super.init()
		protocolType = .EndMessage
		windowSize = endMessageWithWindowSize
		let data = NSMutableData()
		data.appendBytes(&protocolType, length: sizeof(protocolType.rawValue.dynamicType))
		data.appendBytes(&self.windowSize, length: sizeof(windowSize.self.dynamicType))
		self.data = data
	}
	
	/**
	Creates an end part control message with window size.
	
	- parameter endPartWithWindowSize: The window size of the current part.
	
	- returns: BLEPlusSerialServiceMessage
	*/
	public init(endPartWithWindowSize:BLEPlusSerialServiceWindowSizeType) {
		super.init()
		protocolType = .EndPart
		windowSize = endPartWithWindowSize
		let data = NSMutableData()
		data.appendBytes(&protocolType, length: sizeof(protocolType.self.dynamicType))
		data.appendBytes(&self.windowSize, length: sizeof(windowSize.self.dynamicType))
		self.data = data
	}
	
	/**
	Creates a new large message control message with the expected size of data transfer.
	
	- parameter newFileMessageWithExpectedSize: The expected data size.
	
	- returns: BLEPlusSerialServiceMessage
	*/
	public init(newFileMessageWithExpectedSize:UInt64, messageType:BLEPlusSerialServiceMessageType_Type, messageId:BLEPLusSerialServiceMessageIdType) {
		super.init()
		protocolType = .NewFileMessage
		messageSize = newFileMessageWithExpectedSize
		var noMessageSize = CFSwapInt64HostToBig(messageSize)
		self.messageType = messageType
		self.messageId = messageId
		let data = NSMutableData()
		data.appendBytes(&protocolType, length: sizeof(protocolType.rawValue.dynamicType))
		data.appendBytes(&self.messageType, length: sizeof(messageType.self.dynamicType))
		data.appendBytes(&self.messageId, length: sizeof(self.messageId.self.dynamicType))
		data.appendBytes(&noMessageSize, length: sizeof(messageSize.self.dynamicType))
		self.data = data
	}
	
	/**
	Creates a new message control message with the expected size of the data transfer.
	
	- parameter newMessageWithExpectedSize: Expected data transfer size.
	
	- returns: BLEPlusSerialServiceMessage
	*/
	public init(newMessageWithExpectedSize:UInt64, messageType:BLEPlusSerialServiceMessageType_Type, messageId:BLEPLusSerialServiceMessageIdType) {
		super.init()
		protocolType = .NewMessage
		messageSize = newMessageWithExpectedSize
		var noMessageSize = CFSwapInt64HostToBig(messageSize)
		self.messageType = messageType
		self.messageId = messageId
		let data = NSMutableData()
		data.appendBytes(&protocolType, length: sizeof(protocolType.rawValue.dynamicType))
		data.appendBytes(&self.messageType, length: sizeof(self.messageType.self.dynamicType))
		data.appendBytes(&self.messageId, length: sizeof(self.messageId.self.dynamicType))
		data.appendBytes(&noMessageSize, length: sizeof(messageSize.self.dynamicType))
		self.data = data
	}
	
	/**
	Creates a new data message with provided data. The data should include a 1 byte packet number before the payload.
	
	- parameter dataMessageWithData:	NSData
	
	- returns: BLEPlusSerialServiceMessage
	*/
	public init(dataMessageWithData:NSData?) {
		protocolType = .Data
		if let _data = dataMessageWithData {
			let data = NSMutableData()
			data.appendBytes(&protocolType, length: 1)
			data.appendData(_data)
			self.data = data
			self.packetPayload = _data.subdataWithRange(NSRange.init(location: 1, length: _data.length-1))
		}
	}
	
	/**
	Test whether or not this message is valid.
	
	- returns: Bool
	*/
	public func isValidControlMessage() -> Bool {
		return protocolType.rawValue <= BLEPlusSerialServiceProtocolMessageType.Abort.rawValue
	}
	
}
