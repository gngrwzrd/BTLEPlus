//
//  BLEPlusTestMessageProvider.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/27/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class BTLEPlusTestMessageProvider : XCTestCase {
	
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
		//s / d is just junk here
		let s = "FE88CE32-6863-4C13-A6E0-543C087315E3"
		let d = s.dataUsingEncoding(NSUTF8StringEncoding)
		
		let provider = BTLEPlusSerialServicePacketProvider(withData: d!)
		guard let _provider = provider else {
			assert(false)
		}
		_provider.windowSize = 32
		_provider.mtu = 1024
		_provider.lastPacketCounterStart = 0
		_provider.bytesWritten = 40000
		_provider.resendFromPacket(10)
		
		// Test new bytes written. When resend happens the bytes written is reduced
		// by the remaining bytes to be sent.
		let newBytesWrittenAfterResend = UInt64( 40000 - ((32-10) * 1024) )
		assert(_provider.bytesWritten == newBytesWrittenAfterResend)
		assert(_provider.packetCounter == 10)
		assert(_provider.gotPacketCount == 10)
		
		//when packet counter loops
		_provider.lastPacketCounterStart = 124
		_provider.resendFromPacket(4)
		assert(_provider.packetCounter == 4)
		assert(_provider.gotPacketCount == 8)
	}
	
	func testBadURL() {
		let url = NSURL()
		let _provider = BTLEPlusSerialServicePacketProvider(withFileURLForReading: url)
		assert(_provider == nil)
	}
	
	func testZeroData() {
		let data = NSMutableData()
		let _provider = BTLEPlusSerialServicePacketProvider(withData: data)
		assert(_provider == nil)
	}
}
