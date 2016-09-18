//
//  BLEPlusTestControlMssage.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/28/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class BTLEPlusTestProtocolMessage : XCTestCase {
	
	func testIsValid() {
		let data = NSMutableData()
		var type:UInt8  = 20
		data.appendBytes(&type, length: 1)
		let message = BTLEPlusSerialServiceProtocolMessage(withData: data)
		assert(message == nil)
	}
	
	func testWindowSizeMax() {
		let message = BTLEPlusSerialServiceProtocolMessage(withType: .Ack)
		message.windowSize = 200
		assert(message.windowSize == 128)
	}
	
	func testAck() {
		let ack = BTLEPlusSerialServiceProtocolMessage(withType: .Ack)
		let ack2 = BTLEPlusSerialServiceProtocolMessage(withData: ack.data!)
		assert(ack2?.protocolType == .Ack)
	}
	
	func testSendTXInfo() {
		let mtu:UInt16 = 20
		let ws:UInt8 = 64
		let txinfo = BTLEPlusSerialServiceProtocolMessage(peerInfoMessageWithMTU:mtu, windowSize: ws)
		let txinfo2 = BTLEPlusSerialServiceProtocolMessage(withData: txinfo.data!)
		assert(txinfo2?.protocolType == .PeerInfo)
		assert(txinfo2?.mtu == mtu)
		assert(txinfo2?.windowSize == ws)
	}
	
	func testNewMessage() {
		let messageSize:UInt64 = 1024
		let newMessage = BTLEPlusSerialServiceProtocolMessage(newMessageWithExpectedSize: messageSize, messageType: 1, messageId: 1)
		let newMessage2 = BTLEPlusSerialServiceProtocolMessage(withData: newMessage.data!)
		assert(newMessage2?.messageSize == messageSize)
		assert(newMessage2?.protocolType == .NewMessage)
		assert(newMessage2?.messageType == 1)
		assert(newMessage2?.messageId == 1)
	}
	
	func testNewLargeMessage() {
		let messageSize:UInt64 = 1024
		let newMessage = BTLEPlusSerialServiceProtocolMessage(newFileMessageWithExpectedSize: messageSize, messageType: 1, messageId: 1)
		let newMessage2 = BTLEPlusSerialServiceProtocolMessage(withData: newMessage.data!)
		assert(newMessage2?.messageSize == messageSize)
		assert(newMessage2?.protocolType == .NewFileMessage)
	}
	
	func testEndMessage() {
		let windowSize:UInt8 = 23
		let endMessage = BTLEPlusSerialServiceProtocolMessage(endMessageWithWindowSize: windowSize)
		let endMessage2 = BTLEPlusSerialServiceProtocolMessage(withData: endMessage.data!)
		assert(endMessage2?.windowSize == windowSize)
	}
	
	func testResendFromPacket() {
		let resend:UInt8 = 127
		let resendMessage = BTLEPlusSerialServiceProtocolMessage(resendMessageWithStartFromPacket: resend)
		let resendMessage2 = BTLEPlusSerialServiceProtocolMessage(withData: resendMessage.data!)
		assert(resendMessage2?.resendFromPacket == 127)
	}
	
	func testEndpart() {
		let message = BTLEPlusSerialServiceProtocolMessage(endPartWithWindowSize: 64)
		let message2 = BTLEPlusSerialServiceProtocolMessage(withData: message.data!)
		assert(message2?.protocolType == .EndPart)
		assert(message2?.windowSize == message.windowSize)
	}
	
	func testDataMessage() {
		let data = NSMutableData(capacity: 9)
		var d:UInt64 = 904349023
		var packet:BTLEPlusSerialServicePacketCounter_Type = 10
		data!.appendBytes(&packet, length: 1)
		data!.appendBytes(&d, length:8)
		let message = BTLEPlusSerialServiceProtocolMessage(dataMessageWithData: data)
		let message2 = BTLEPlusSerialServiceProtocolMessage(withData: message.data!)
		assert(message.protocolType == .Data)
		assert(message2?.packetPayload != nil)
		let out = message2?.packetPayload!
		out?.getBytes(&packet,length:1)
		out?.getBytes(&d, range: NSRange.init(location:1, length:8))
		assert(d == 904349023)
		assert(packet == 10)
	}
}