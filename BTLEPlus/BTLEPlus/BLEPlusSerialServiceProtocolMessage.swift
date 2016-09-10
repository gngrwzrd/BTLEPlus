//
//  BLEPlusSerialServiceControlMessage.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/23/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

/// The type to use for message type.
public typealias BLEPlusSerialServiceMessageType_Type = UInt8

/// The type to use for message id.
public typealias BLEPLusSerialServiceMessageId_Type = UInt8

/// The type to use for window size.
public typealias BLEPlusSerialServiceWindowSize_Type = UInt8

/// The type to use for maximum transmission unit.
public typealias BLEPlusSerialServiceMTU_Type = UInt16

/// The default maximum transmission unit. Upon connection, peers
/// exchange their information and agree on an mtu and window size to use.
/// It's likely that the agreed upon mtu will be a lot less.
public let BLEPlusSerialServiceDefaultMTU:UInt16 = UInt16.max

/// The default window size. Window size is how many mtu buffers are available to send
/// or receive. Total bytes in the window = windowSize * mtu.
public var BLEPlusSerialServiceDefaultWindowSize:BLEPlusSerialServiceWindowSize_Type = 32

/// The largest possible window size. This is use to clamp user provided window sizes
/// which are not allowed to be larger than this.
public var BLEPlusSerialServiceMaxWindowSize:BLEPlusSerialServiceWindowSize_Type = 128

/// The default max message id value before it loops to zero.
public var BLEPlusSerialServiceMaxMessageId:BLEPLusSerialServiceMessageId_Type = BLEPLusSerialServiceMessageId_Type.max

/// Returns a value as big endian order.
func byteSwapToBigEndian<T>(value:T) -> T {
	let size = sizeof(value.dynamicType)
	if size == 2 {
		let swapped16 = CFSwapInt16HostToBig( value as! UInt16 )
		return swapped16 as! T
	}
	if size == 4 {
		let swapped32 = CFSwapInt32HostToBig( value as! UInt32 )
		return swapped32 as! T
	}
	if size == 8 {
		let swapped64 = CFSwapInt64HostToBig( value as! UInt64 )
		return swapped64 as! T
	}
	return value
}

/// Returns a value as host byte order.
func byteSwapToHost<T>(value:T) -> T {
	let size = sizeof(value.dynamicType)
	if size == 2 {
		let swapped16 = CFSwapInt16BigToHost( value as! UInt16 )
		return swapped16 as! T
	}
	if size == 4 {
		let swapped32 = CFSwapInt32BigToHost( value as! UInt32 )
		return swapped32 as! T
	}
	if size == 8 {
		let swapped64 = CFSwapInt64BigToHost( value as! UInt64 )
		return swapped64 as! T
	}
	return value
}

/// Extension for NSData to print the data as hex values
extension NSData {
	
	/// print data as hex values
	func bleplus_base16EncodedString(uppercase uppercase: Bool = false) -> String {
		let buffer = UnsafeBufferPointer<UInt8>(start: UnsafePointer(self.bytes),count: self.length)
		let hexFormat = uppercase ? "X" : "x"
		let formatString = "0x%02\(hexFormat) "
		//let asciiFormat = "%c "
		let bytesAsHexStrings = buffer.map {
			String(format: formatString, $0)
		}
		return bytesAsHexStrings.joinWithSeparator("")
	}
}

/**
Control message types.

- None:              None.
- PeerInfo:          Peer transfer information.
- Ack:               Acknowledge.
- NewMessage:        Client or server is requesting to send a new message.
- NewFileMessage:    Client or server is requesting to send a new file message.
- EndPart:           End the current window.
- EndMessage:        End the current message.
- Resend:            Resend the current window.
- Data:              Data message.
- TakeTurn:          The peers turn to send messages.
- Abort:             Abort the current state and reset. Allow the central to start over.
*/
@objc enum BLEPlusSerialServiceProtocolMessageType : BLEPlusSerialServiceProtocolMessageType_Type {
	case None = 0
	case PeerInfo = 1
	case Ack = 2
	case NewMessage = 3
	case NewFileMessage = 4
	case EndPart = 5
	case EndMessage = 6
	case Data = 7
	case Resend = 8
	case TakeTurn = 9
	case Abort = 10
}

/// BLEPlusSerialServiceMessage is used over the control channel
/// to communicate what's happening on the transfer channel.
@objc class BLEPlusSerialServiceProtocolMessage : NSObject {
	
	/// The size of the header for a BLEPlusSerialServiceMessage.
	/// Default value is 1 byte for the message type.
	static var headerSize:UInt8 = 1
	
	/// Message type
	var protocolType:BLEPlusSerialServiceProtocolMessageType = .None
	
	/// A custom user message type.
	var messageType:UInt8 = 0
	
	/// A custom user message id.
	var messageId:BLEPLusSerialServiceMessageId_Type = 0
	
	/// Raw message data.
	var data:NSData? = nil
	
	/// For data messages, this is the packet data stripped of the type header.
	var packetPayload:NSData?
	
	/// Maximum Transmission Unit
	var mtu:BLEPlusSerialServiceMTU_Type = 0
	
	/// Window size. This is clamped between 0 and BLEPlusSerialServiceMaxWindowSize.
	var windowSize:BLEPlusSerialServiceWindowSize_Type {
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
	private var _windowSize:BLEPlusSerialServiceWindowSize_Type = BLEPlusSerialServiceDefaultWindowSize
	
	/// The packet to resend data from.
	var resendFromPacket:BLEPlusSerialServicePacketCountType = 0
	
	/// The expected message size.
	var messageSize:UInt64 = 0
	
	/**
	Initialize with the control type. This is only used when there is no other
	data required as part of the message
	
	- parameter withType: The control message type.
	
	- returns: BLEPlusSerialServiceMessage
	*/
	init(withType:BLEPlusSerialServiceProtocolMessageType) {
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
	init?(withData data:NSData) {
		super.init()
		self.data = data
		data.getBytes(&protocolType, range: NSRange.init(location:0, length: sizeof(protocolType.rawValue.dynamicType)))
		
		if isValidControlMessage() {
			
			if protocolType == .PeerInfo {
				var noMTU:UInt16 = 0
				data.getBytes(&noMTU, range: NSRange.init(location: sizeof(protocolType.rawValue.dynamicType), length: sizeof(mtu.dynamicType)))
				self.mtu = byteSwapToHost(noMTU)
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
				messageSize = byteSwapToHost(noMessageSize)
			}
			
			if protocolType == .EndMessage || protocolType == .EndPart {
				data.getBytes(&windowSize, range: NSRange.init(location: sizeof(protocolType.rawValue.dynamicType), length: sizeof(windowSize.dynamicType)))
			}
			
			if protocolType == .Data {
				packetPayload = data.subdataWithRange(NSRange.init(location: 1, length: data.length-1))
			}
			
		} else {
			return nil
		}
	}
	
	/**
	Create a peer info message with MTU and window size.
	
	- parameter peerInfoMessageWithMTU:	Maximum transmission unit.
	- parameter windowSize:							Window size. Max is 64
	
	- returns: BLEPlusSerialServiceMessage
	*/
	init(peerInfoMessageWithMTU:BLEPlusSerialServiceMTU_Type, windowSize:BLEPlusSerialServiceWindowSize_Type) {
		super.init()
		protocolType = .PeerInfo
		mtu = peerInfoMessageWithMTU
		self.windowSize = windowSize
		let data = NSMutableData()
		var noMTU = byteSwapToBigEndian(mtu)
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
	init(resendMessageWithStartFromPacket:BLEPlusSerialServicePacketCountType) {
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
	init(endMessageWithWindowSize:BLEPlusSerialServiceWindowSize_Type) {
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
	init(endPartWithWindowSize:BLEPlusSerialServiceWindowSize_Type) {
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
	init(newFileMessageWithExpectedSize:UInt64, messageType:BLEPlusSerialServiceMessageType_Type, messageId:BLEPLusSerialServiceMessageId_Type) {
		super.init()
		protocolType = .NewFileMessage
		messageSize = newFileMessageWithExpectedSize
		var noMessageSize = byteSwapToBigEndian(messageSize)
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
	init(newMessageWithExpectedSize:UInt64, messageType:BLEPlusSerialServiceMessageType_Type, messageId:BLEPLusSerialServiceMessageId_Type) {
		super.init()
		protocolType = .NewMessage
		messageSize = newMessageWithExpectedSize
		var noMessageSize = byteSwapToBigEndian(messageSize)
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
	init(dataMessageWithData:NSData?) {
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
	func isValidControlMessage() -> Bool {
		return protocolType.rawValue <= BLEPlusSerialServiceProtocolMessageType.Abort.rawValue
	}
	
}
