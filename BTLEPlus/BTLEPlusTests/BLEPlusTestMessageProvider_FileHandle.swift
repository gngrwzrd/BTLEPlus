//
//  BLEPlusTestMessageProvider.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/26/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class BLEPlusTestMessageProvider_FileHandle : XCTestCase {
	
	var testMTU:BLEPlusSerialServiceMTUType = 0
	var testRealMTU:BLEPlusSerialServiceMTUType = 0
	var testWindowSize:BLEPlusSerialServiceWindowSize_Type = 0
	
	override func setUp() {
		testMTU = 1024
		testRealMTU = UInt16(testMTU - UInt16((BLEPlusSerialServicePacketProvider.headerSize + BLEPlusSerialServiceProtocolMessage.headerSize)))
		testWindowSize = 25
	}
	
	func testGetPacketLengthMatchesMTU() {
		let fileURL = NSBundle(forClass: self.dynamicType).URLForImageResource("IMG_5543")
		let _provider = BLEPlusSerialServicePacketProvider.createWithFileURLForReading(fileURL!, mtu: testMTU, windowSize: testWindowSize)
		guard let provider = _provider else {
			assert(false)
		}
		provider.fillWindow()
		let packet = provider.getPacket()
		assert(packet.length == Int(testRealMTU) + sizeof(provider.packetCounter.dynamicType))
	}
	
	func testGetPart() {
		let fileURL = NSBundle(forClass: self.dynamicType).URLForImageResource("IMG_5543")
		let _provider = BLEPlusSerialServicePacketProvider.createWithFileURLForReading(fileURL!, mtu: testMTU, windowSize: testWindowSize)
		guard let provider = _provider else {
			assert(false)
		}
		provider.fillWindow()
		var i:UInt8 = 0
		var packet:NSData? = nil
		var packetCounter:UInt8 = 0
		while(i < UInt8(provider.windowSize)) {
			packet = provider.getPacket()
			assert(packet!.length == Int(testRealMTU) + sizeof(provider.packetCounter.dynamicType))
			packet?.getBytes(&packetCounter, range: NSRange.init(location: 0, length: sizeof(packetCounter.dynamicType) ))
			assert(packetCounter == i)
			i = i + 1
		}
		assert(provider.bytesWritten == UInt64(testRealMTU * 25))
		provider.finishMessage()
	}
	
	func testGetMultipleParts() {
		let fileURL = NSBundle(forClass: self.dynamicType).URLForImageResource("IMG_5543")
		let _provider = BLEPlusSerialServicePacketProvider.createWithFileURLForReading(fileURL!, mtu: testMTU, windowSize: testWindowSize)
		guard let provider = _provider else {
			assert(false)
		}
		
		//first round of get packets
		provider.fillWindow()
		var i:UInt8 = 0
		var packet:NSData? = nil
		var packetCounter:UInt8 = 0
		while(i < UInt8(provider.windowSize)) {
			packet = provider.getPacket()
			assert(packet!.length == Int(testRealMTU) + sizeof(provider.packetCounter.dynamicType))
			packet?.getBytes(&packetCounter, range: NSRange.init(location: 0, length: sizeof(packetCounter.dynamicType) ))
			assert(packetCounter == i)
			i = i + 1
		}
		assert(packetCounter == 24)
		
		//save last packet counter to compare next part and round of packet counter
		let lastPacketCounter = packetCounter
		
		//fill more packets
		provider.fillWindow()
		i = 0
		while (i < UInt8(provider.windowSize)) {
			packet = provider.getPacket()
			assert(packet!.length == Int(testRealMTU) + sizeof(provider.packetCounter.dynamicType))
			packet?.getBytes(&packetCounter, range: NSRange.init(location: 0, length: sizeof(packetCounter.dynamicType) ))
			i = i + 1
			assert(packetCounter == i + lastPacketCounter)
		}
		
		assert(provider.bytesWritten == UInt64(testRealMTU * UInt16((testWindowSize * 2))))
		
		provider.finishMessage()
	}
	
	func testResendFromPacket() {
		let fileURL = NSBundle(forClass: self.dynamicType).URLForImageResource("IMG_5543")
		let _provider = BLEPlusSerialServicePacketProvider.createWithFileURLForReading(fileURL!, mtu: testMTU, windowSize: testWindowSize)
		guard let provider = _provider else {
			assert(false)
		}
		provider.fillWindow()
		provider.resendFromPacket(10)
		var i:UInt8 = 10
		var packet:NSData? = nil
		var packetCounter:UInt8 = 0
		while(i < UInt8(provider.windowSize)) {
			packet = provider.getPacket()
			assert(packet!.length == Int(testRealMTU)  + sizeof(provider.packetCounter.dynamicType))
			packet?.getBytes(&packetCounter, range: NSRange.init(location: 0, length: sizeof(packetCounter.dynamicType) ))
			assert(packetCounter == i)
			i = i + 1
		}
		provider.finishMessage()
	}
	
	func testResendWindow() {
		let fileURL = NSBundle(forClass: self.dynamicType).URLForImageResource("IMG_5543")
		let _provider = BLEPlusSerialServicePacketProvider.createWithFileURLForReading(fileURL!, mtu: testMTU, windowSize: testWindowSize)
		guard let provider = _provider else {
			assert(false)
		}
		provider.fillWindow()
		var i:UInt8 = 0
		var packet:NSData? = nil
		var packetCounter:UInt8 = 0
		while(i < UInt8(provider.windowSize)) {
			packet = provider.getPacket()
			assert(packet!.length == Int(testRealMTU) + sizeof(provider.packetCounter.dynamicType))
			packet?.getBytes(&packetCounter, range: NSRange.init(location: 0, length: sizeof(packetCounter.dynamicType) ))
			assert(packetCounter == i)
			i = i + 1
		}
		provider.resendWindow()
		assert(provider.packetCounter == 0)
		i = 0
		while(i < UInt8(provider.windowSize)) {
			packet = provider.getPacket()
			assert(packet!.length == Int(testRealMTU) + sizeof(provider.packetCounter.dynamicType))
			packet?.getBytes(&packetCounter, range: NSRange.init(location: 0, length: sizeof(packetCounter.dynamicType) ))
			assert(packetCounter == i)
			i = i + 1
		}
		provider.finishMessage()
	}
	
	func testAllParts() {
		let fileURL = NSBundle(forClass: self.dynamicType).URLForImageResource("IMG_5543")
		let _provider = BLEPlusSerialServicePacketProvider.createWithFileURLForReading(fileURL!, mtu: testMTU, windowSize: testWindowSize)
		guard let provider = _provider else {
			assert(false)
		}
		while(true) {
			provider.fillWindow()
			var i:UInt8 = 0
			while(i < provider.windowSize) {
				_ = provider.getPacket()
				i = i + 1
				if provider.isEndOfMessage {
					break
				}
			}
			if provider.isEndOfMessage {
				break
			}
			print(provider.bytesWritten)
		}
		assert(provider.packets.count == Int(provider.endOfMessageWindowSize))
		assert(provider.bytesWritten == provider.messageSize)
	}
	
	func testPacketError() {
		let fileURL = NSBundle(forClass: self.dynamicType).URLForImageResource("IMG_5543")
		let _provider = BLEPlusSerialServicePacketProvider.createWithFileURLForReading(fileURL!, mtu: testMTU, windowSize: testWindowSize)
		guard let provider = _provider else {
			assert(false)
		}
		_ = provider.fillWindow()
	}
	
	func testWriteImageFromProvider() {
		let fileURL = NSBundle(forClass: self.dynamicType).URLForImageResource("IMG_5543")
		let _provider = BLEPlusSerialServicePacketProvider.createWithFileURLForReading(fileURL!, mtu: testMTU, windowSize: testWindowSize)
		let outputImageURL = BLEPlusSerialServicePacketReceiver.getTempFileForWriting()
		print(outputImageURL)
		let outputImage = NSFileHandle(forWritingAtPath: outputImageURL!.path!)
		guard let provider = _provider else {
			assert(false)
		}
		var packet:NSData? = nil
		var payload:NSData? = nil
		var bytesWritten:UInt64 = 0
		while true {
			provider.fillWindow()
			while provider.hasPackets() {
				packet = provider.getPacket()
				payload = packet!.subdataWithRange(NSRange.init(location: sizeof(provider.packetCounter.self.dynamicType) , length: packet!.length - sizeof(provider.packetCounter.self.dynamicType)))
				outputImage!.writeData(payload!)
				bytesWritten = bytesWritten + UInt64(payload!.length)
			}
			if provider.isEndOfMessage {
				break
			}
		}
		assert(provider.messageSize == bytesWritten)
		provider.finishMessage()
	}
}
