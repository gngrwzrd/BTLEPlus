//
//  BLEPlusTestMessageReceiver_NSFileHandle.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/26/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class BLEPlusTestMessageReceiver_NSFileHandle : XCTestCase {
	
	func testTransferFileFromProviderToReceiver() {
		let fileURL = NSBundle(forClass: self.dynamicType).URLForImageResource("IMG_5595")
		let _provider = BTLEPlusSerialServicePacketProvider(withFileURLForReading: fileURL!)
		_provider?.mtu = 1024
		_provider?.windowSize = 25
		let _fileWrite = BTLEPlusSerialServicePacketReceiver.getTempFileForWriting()
		let _receiver = BTLEPlusSerialServicePacketReceiver(withFileURLForWriting: _fileWrite!, windowSize: 25)
		guard let receiver = _receiver else {
			assert(false)
		}
		guard let provider = _provider else {
			assert(false)
		}
		var packet:NSData? = nil
		receiver.beginMessage()
		while(true) {
			if provider.isEndOfMessage {
				break
			}
			provider.fillWindow()
			receiver.beginWindow()
			receiver.windowSize = provider.windowSize
			if provider.isEndOfMessage {
				receiver.windowSize = provider.endOfMessageWindowSize
			}
			while provider.hasPackets() {
				packet = provider.getPacket()
				receiver.receivedData(packet!)
			}
			assert(receiver.needsPacketsResent == false)
			receiver.commitPacketData()
		}
		if provider.isEndOfMessage {
			receiver.windowSize = provider.windowSize
			receiver.commitPacketData()
			assert(provider.bytesWritten == receiver.bytesReceived)
			provider.finishMessage()
			receiver.commitPacketData()
			receiver.finishMessage()
		}
	}
	
	func testResendPacketFrom() {
		let _receiver = BTLEPlusSerialServicePacketReceiver(withWindowSize: 25)
		guard let receiver = _receiver else {
			assert(false)
		}
		let data = NSMutableData(capacity: 2)
		var packet:UInt8 = 1
		var garbage:UInt8 = 5
		data?.replaceBytesInRange(NSRange.init(location: 0, length: 1), withBytes: &packet)
		data?.replaceBytesInRange(NSRange.init(location: 1, length: 1), withBytes: &garbage)
		receiver.receivedData(data!)
		assert(receiver.needsPacketsResent)
		assert(receiver.resendFromPacket == 0)
	}
	
	func testResendPacketFrom2() {
		let _receiver = BTLEPlusSerialServicePacketReceiver(withWindowSize: 25)
		guard let receiver = _receiver else {
			assert(false)
		}
		let data = NSMutableData(capacity: 2)
		var packet:UInt8 = 10
		var garbage:UInt8 = 5
		data?.replaceBytesInRange(NSRange.init(location: 0, length: 1), withBytes: &packet)
		data?.replaceBytesInRange(NSRange.init(location: 1, length: 1), withBytes: &garbage)
		receiver.receivedData(data!)
		assert(receiver.needsPacketsResent)
		assert(receiver.resendFromPacket == 0)
	}
	
}
