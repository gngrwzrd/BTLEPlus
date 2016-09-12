//
//  BLEPlusTestMessageReceiver.swift
//  BLEPlus
//
//  Created by Aaron Smith on 8/27/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class BLEPlusTestMessageReceiver : XCTestCase {
	
	func testWindowSizeMax() {
		let _receiver = BTLEPlusSerialServicePacketReceiver(withWindowSize: 200)
		assert(_receiver!.windowSize == BTLEPlusSerialServiceMaxWindowSize)
	}
	
}
