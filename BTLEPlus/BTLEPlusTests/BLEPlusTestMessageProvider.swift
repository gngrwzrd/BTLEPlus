//
//  BLEPlusTestMessageProvider.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/27/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class BLEPlusTestMessageProvider : XCTestCase {
	
	func testWindowSizeMax() {
		let fileURL = NSBundle(forClass: self.dynamicType).URLForImageResource("IMG_5543")
		let _provider = BTLEPlusSerialServicePacketProvider(withFileURLForReading: fileURL!)
		_provider?.mtu = 1024
		_provider?.mtu = 25
		_provider!.windowSize = 200
		assert(_provider!.windowSize == BTLEPlusSerialServiceMaxWindowSize)
	}
	
	func testCreateReturnsNil() {
		let url:NSURL = NSURL(fileURLWithPath: "/test")
		let provider = BTLEPlusSerialServicePacketProvider(withFileURLForReading: url)
		assert(provider == nil)
	}
	
	func testResendFromPacket() {
		let _provider = BTLEPlusSerialServicePacketProvider()
		_provider.windowSize = 32
		_provider.mtu = 1024
		_provider.lastPacketCounterStart = 0
		_provider.resendFromPacket(10)
		assert(_provider.packetCounter == 10)
		assert(_provider.gotPacketCount == 10)
		
		//when packet counter loops
		_provider.lastPacketCounterStart = 124
		_provider.resendFromPacket(4)
		assert(_provider.packetCounter == 4)
		assert(_provider.gotPacketCount == 8)
		
	}
	
}
