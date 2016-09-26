//
//  BTLEPlusSerialServiceMessageTests.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/25/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class BTLEPlusSerialServiceMessageTests : XCTestCase {
	
	func testReturnsNilWithZeroData() {
		let data = NSData()
		let message = BTLEPlusSerialServiceMessage(withMessageType: 0, messageId: 0, data: data)
		assert(message == nil)
	}
	
	func testFileURL() {
		let fileURL = NSBundle(forClass: self.dynamicType).URLForImageResource("IMG_5543")
		let message = BTLEPlusSerialServiceMessage(withMessageType: 1, messageId: 1, fileURL: fileURL!)
		assert(message != nil)
	}
	
	func testBadPath() {
		let fileURL = NSURL()
		let message = BTLEPlusSerialServiceMessage(withMessageType: 1, messageId: 1, fileURL: fileURL)
		assert(message == nil)
	}
	
	func testFile404() {
		let fileURL = NSURL(fileURLWithPath: "/var/tmp/404")
		let message = BTLEPlusSerialServiceMessage(withMessageType: 1, messageId: 1, fileURL: fileURL)
		assert(message == nil)
	}
}
