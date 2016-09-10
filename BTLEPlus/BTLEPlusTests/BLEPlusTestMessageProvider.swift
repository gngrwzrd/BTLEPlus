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
		let _provider = BLEPlusSerialServicePacketProvider(withFileURLForReading: fileURL!)
		_provider?.mtu = 1024
		_provider?.mtu = 25
		_provider!.windowSize = 200
		assert(_provider!.windowSize == BLEPlusSerialServiceMaxWindowSize)
	}
	
	func testCreateReturnsNil() {
		let url:NSURL = NSURL(fileURLWithPath: "/test")
		let provider = BLEPlusSerialServicePacketProvider(withFileURLForReading: url)
		assert(provider == nil)
	}
	
}
