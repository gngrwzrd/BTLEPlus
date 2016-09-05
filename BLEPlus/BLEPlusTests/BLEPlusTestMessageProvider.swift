//
//  BLEPlusTestMessageProvider.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/27/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BLEPlus

class BLEPlusTestMessageProvider : XCTestCase {
	
	func testWindowSizeMax() {
		let fileURL = NSBundle(forClass: self.dynamicType).URLForImageResource("IMG_5543")
		let _provider = BLEPlusSerialServicePacketProvider.createWithFileURLForReading(fileURL!, mtu: 1024, windowSize: 25)
		_provider!.windowSize = 200
		assert(_provider!.windowSize == BLEPlusSerialServiceMaxWindowSize)
	}
	
	func testCreateReturnsNil() {
		let url:NSURL = NSURL(fileURLWithPath: "/test")
		let provider = BLEPlusSerialServicePacketProvider.createWithFileURLForReading(url, mtu: 10, windowSize: 10)
		assert(provider == nil)
	}
	
}
