//
//  BLEPlusTestControlMssage.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/28/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class BLEPlusTestUserMessage : XCTestCase {
	
	func testWindowSizeMax() {
		let message = BLEPlusSerialServiceProtocolMessage(withType: .Ack)
		message.windowSize = 200
		assert(message.windowSize == 128)
	}
	
	func testAck() {
		let ack = BLEPlusSerialServiceProtocolMessage(withType: .Ack)
		let ack2 = BLEPlusSerialServiceProtocolMessage(withData: ack.data)
		assert(ack2.protocolType == .Ack)
	}
	
	func testSendTXInfo() {
		let mtu:UInt16 = 20
		let ws:UInt8 = 64
		let txinfo = BLEPlusSerialServiceProtocolMessage(peerInfoMessageWithMTU:mtu, windowSize: ws)
		let txinfo2 = BLEPlusSerialServiceProtocolMessage(withData: txinfo.data)
		assert(txinfo2.protocolType == .PeerInfo)
		assert(txinfo2.mtu == mtu)
		assert(txinfo2.windowSize == ws)
	}
	
	func testNewMessage() {
		let messageSize:UInt64 = 1024
		let newMessage = BLEPlusSerialServiceProtocolMessage(newMessageWithExpectedSize: messageSize, messageType: 1, messageId: 1)
		let newMessage2 = BLEPlusSerialServiceProtocolMessage(withData: newMessage.data)
		assert(newMessage2.messageSize == messageSize)
		assert(newMessage2.protocolType == .NewMessage)
		assert(newMessage2.messageType == 1)
		assert(newMessage2.messageId == 1)
	}
	
	func testNewLargeMessage() {
		let messageSize:UInt64 = 1024
		let newMessage = BLEPlusSerialServiceProtocolMessage(newFileMessageWithExpectedSize: messageSize, messageType: 1, messageId: 1)
		let newMessage2 = BLEPlusSerialServiceProtocolMessage(withData: newMessage.data)
		assert(newMessage2.messageSize == messageSize)
		assert(newMessage2.protocolType == .NewFileMessage)
	}
	
	func testEndMessage() {
		let windowSize:UInt8 = 23
		let endMessage = BLEPlusSerialServiceProtocolMessage(endMessageWithWindowSize: windowSize)
		let endMessage2 = BLEPlusSerialServiceProtocolMessage(withData: endMessage.data)
		assert(endMessage2.windowSize == windowSize)
	}
	
	func testResendFromPacket() {
		let resend:UInt8 = 127
		let resendMessage = BLEPlusSerialServiceProtocolMessage(resendMessageWithStartFromPacket: resend)
		let resendMessage2 = BLEPlusSerialServiceProtocolMessage(withData: resendMessage.data)
		assert(resendMessage2.resendFromPacket == 127)
	}
	
	func testEndpart() {
		let message = BLEPlusSerialServiceProtocolMessage(endPartWithWindowSize: 64)
		let message2 = BLEPlusSerialServiceProtocolMessage(withData: message.data)
		assert(message2.protocolType == .EndPart)
		assert(message2.windowSize == BLEPlusSerialServiceMaxWindowSize)
	}
	
	func testDataMessage() {
		let data = NSMutableData(capacity: 9)
		var d:UInt64 = 904349023
		var packet:BLEPlusSerialServicePacketCountType = 10
		data!.appendBytes(&packet, length: 1)
		data!.appendBytes(&d, length:8)
		let message = BLEPlusSerialServiceProtocolMessage(dataMessageWithData: data)
		let message2 = BLEPlusSerialServiceProtocolMessage(withData: message.data)
		assert(message.protocolType == .Data)
		assert(message2.packetPayload != nil)
		let out = message2.packetPayload!
		out.getBytes(&packet,length:1)
		out.getBytes(&d, range: NSRange.init(location:1, length:8))
		assert(d == 904349023)
		assert(packet == 10)
	}
}