//
//  BTLEPlusSerialServiceControlMessage.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 8/23/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

/// The type to use for message type.
public typealias BTLEPlusSerialServiceMessageType_Type = UInt16

/// The type to use for message id.
public typealias BTLEPlusSerialServiceMessageId_Type = UInt16

/// The type to use for window size.
public typealias BTLEPlusSerialServiceWindowSize_Type = UInt8

/// The type to use for maximum transmission unit.
public typealias BTLEPlusSerialServiceMTU_Type = UInt16

/// The default maximum transmission unit. Upon connection, peers
/// exchange their information and agree on an mtu and window size to use.
/// It's likely that the agreed upon mtu will be a lot less.
public let BTLEPlusSerialServiceDefaultMTU:UInt16 = UInt16.max

/// The default window size. Window size is the number of mtu buffers
/// are available to send or receive. Total bytes in the window = windowSize * mtu.
public var BTLEPlusSerialServiceDefaultWindowSize:BTLEPlusSerialServiceWindowSize_Type = 32

/// The largest possible window size. This is use to clamp user provided window sizes
/// which are not allowed to be larger than this.
public var BTLEPlusSerialServiceMaxWindowSize:BTLEPlusSerialServiceWindowSize_Type = 128

/// The default max message id value before it loops to zero.
public var BTLEPlusSerialServiceMaxMessageId:BTLEPlusSerialServiceMessageId_Type = BTLEPlusSerialServiceMessageId_Type.max

/// :nodoc:
/// The type to use for protocol message type.
typealias BTLEPlusSerialServiceProtocolMessageType_Type = UInt8

/// :nodoc:
/// The type to use for packet counting.
typealias BTLEPlusSerialServicePacketCounter_Type = UInt8

/// :nodoc:
/// The default max packet counter before it loops to zero.
var BTLEPlusSerialServiceMaxPacketCounter:BTLEPlusSerialServicePacketCounter_Type = 128


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
- Wait:              The peer should wait and try again to send new messages.
- Abort:             Abort the current state and reset. Allow the central to start over.
*/
@objc enum BTLEPlusSerialServiceProtocolMessageType : BTLEPlusSerialServiceProtocolMessageType_Type {
	case Invalid = 0
	case PeerInfo = 1
	case Ack = 2
	case NewMessage = 3
	case NewFileMessage = 4
	case EndPart = 5
	case EndMessage = 6
	case Data = 7
	case Resend = 8
	case TakeTurn = 9
	case Wait = 10
	case Reset = 11
}

/// BTLEPlusSerialServiceMessage is used over the control channel
/// to communicate what's happening on the transfer channel.
@objc class BTLEPlusSerialServiceProtocolMessage : NSObject {
	
	/// The size of the header for a BLEPlusSerialServiceMessage.
	/// Default value is 1 byte for the message type.
	static var headerSize:UInt8 = 1
	
	/// Message type
	var protocolType:BTLEPlusSerialServiceProtocolMessageType = .Invalid
	
	/// A custom user message type.
	var messageType:BTLEPlusSerialServiceMessageType_Type = 0
	
	/// A custom user message id.
	var messageId:BTLEPlusSerialServiceMessageId_Type = 0
	
	/// Raw message data.
	var data:NSData? = nil
	
	/// For data messages, this is the packet data stripped of the type header.
	var packetPayload:NSData?
	
	/// Maximum Transmission Unit
	var mtu:BTLEPlusSerialServiceMTU_Type = 0
	
	/// Window size. This is clamped between 0 and BLEPlusSerialServiceMaxWindowSize.
	var windowSize:BTLEPlusSerialServiceWindowSize_Type {
		get {
			return _windowSize
		} set(new) {
			if new > BTLEPlusSerialServiceMaxWindowSize || new < 0 {
				_windowSize = BTLEPlusSerialServiceMaxWindowSize
			} else {
				_windowSize = new
			}
		}
	}
	private var _windowSize:BTLEPlusSerialServiceWindowSize_Type = BTLEPlusSerialServiceDefaultWindowSize
	
	/// The packet to resend data from.
	var resendFromPacket:BTLEPlusSerialServicePacketCounter_Type = 0
	
	/// The expected message size.
	var messageSize:UInt64 = 0
	
	/**
	Initialize with the control type. This is only used when there is no other
	data required as part of the message
	
	- parameter withType: The control message type.
	
	- returns: BLEPlusSerialServiceMessage
	*/
	init(withType:BTLEPlusSerialServiceProtocolMessageType) {
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
				self.mtu = CFSwapInt16BigToHost(noMTU)
				data.getBytes(&windowSize, range: NSRange.init(location: sizeof(protocolType.rawValue.dynamicType) + sizeof(mtu.dynamicType), length: sizeof(windowSize.dynamicType)))
			}
			
			if protocolType == .Resend {
				data.getBytes(&resendFromPacket, range: NSRange.init(location: sizeof(protocolType.rawValue.dynamicType), length: sizeof(resendFromPacket.dynamicType)))
			}
			
			if protocolType == .NewMessage || protocolType == .NewFileMessage {
				var noMessageType:BTLEPlusSerialServiceMessageType_Type = 0
				data.getBytes(&noMessageType, range: NSRange.init(location: sizeof(protocolType.rawValue.dynamicType), length: sizeof(messageType.dynamicType)))
				messageType = CFSwapInt16BigToHost(noMessageType)
				
				var noMessageId:BTLEPlusSerialServiceMessageId_Type = 0
				data.getBytes(&noMessageId, range: NSRange.init(location: sizeof(protocolType.rawValue.dynamicType) + sizeof(messageType.dynamicType), length: sizeof(messageId.self.dynamicType)))
				messageId = CFSwapInt16BigToHost(noMessageId)
				
				var noMessageSize:UInt64 = 0
				data.getBytes(&noMessageSize, range: NSRange.init(location: sizeof(protocolType.rawValue.dynamicType) + sizeof(messageType.dynamicType) + sizeof(messageId.self.dynamicType), length: sizeof(messageSize.dynamicType)))
				messageSize = CFSwapInt64BigToHost(noMessageSize)
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
	init(peerInfoMessageWithMTU:BTLEPlusSerialServiceMTU_Type, windowSize:BTLEPlusSerialServiceWindowSize_Type) {
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
	
	- returns: BTLEPlusSerialServiceMessage
	*/
	init(resendMessageWithStartFromPacket:BTLEPlusSerialServicePacketCounter_Type) {
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
	
	- returns: BTLEPlusSerialServiceMessage
	*/
	init(endMessageWithWindowSize:BTLEPlusSerialServiceWindowSize_Type) {
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
	
	- returns: BTLEPlusSerialServiceMessage
	*/
	init(endPartWithWindowSize:BTLEPlusSerialServiceWindowSize_Type) {
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
	
	- returns: BTLEPlusSerialServiceMessage
	*/
	init(newFileMessageWithExpectedSize:UInt64, messageType:BTLEPlusSerialServiceMessageType_Type, messageId:BTLEPlusSerialServiceMessageId_Type) {
		super.init()
		protocolType = .NewFileMessage
		messageSize = newFileMessageWithExpectedSize
		self.messageType = messageType
		self.messageId = messageId
		var noMessageSize = CFSwapInt64HostToBig(messageSize)
		var noMessageType = CFSwapInt16HostToBig(messageType)
		var noMessageId = CFSwapInt16HostToBig(messageId)
		let data = NSMutableData()
		data.appendBytes(&protocolType, length: sizeof(protocolType.rawValue.dynamicType))
		data.appendBytes(&noMessageType, length: sizeof(messageType.self.dynamicType))
		data.appendBytes(&noMessageId, length: sizeof(self.messageId.self.dynamicType))
		data.appendBytes(&noMessageSize, length: sizeof(messageSize.self.dynamicType))
		self.data = data
	}
	
	/**
	Creates a new message control message with the expected size of the data transfer.
	
	- parameter newMessageWithExpectedSize: Expected data transfer size.
	
	- returns: BTLEPlusSerialServiceMessage
	*/
	init(newMessageWithExpectedSize:UInt64, messageType:BTLEPlusSerialServiceMessageType_Type, messageId:BTLEPlusSerialServiceMessageId_Type) {
		super.init()
		protocolType = .NewMessage
		messageSize = newMessageWithExpectedSize
		self.messageType = messageType
		self.messageId = messageId
		var noMessageSize = CFSwapInt64HostToBig(messageSize)
		var noMessageType = CFSwapInt16HostToBig(messageType)
		var noMessageId = CFSwapInt16HostToBig(messageId)
		let data = NSMutableData()
		data.appendBytes(&protocolType, length: sizeof(protocolType.rawValue.dynamicType))
		data.appendBytes(&noMessageType, length: sizeof(self.messageType.self.dynamicType))
		data.appendBytes(&noMessageId, length: sizeof(self.messageId.self.dynamicType))
		data.appendBytes(&noMessageSize, length: sizeof(messageSize.self.dynamicType))
		self.data = data
	}
	
	/**
	Creates a new data message with provided data. The data should include a 1 byte packet number before the payload.
	
	- parameter dataMessageWithData:	NSData
	
	- returns: BTLEPlusSerialServiceMessage
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
		if protocolType.rawValue < 1 {
			return false
		}
		return protocolType.rawValue <= BTLEPlusSerialServiceProtocolMessageType.Reset.rawValue
	}
	
}
