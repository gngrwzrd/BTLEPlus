//
//  BTLEPlusSerialServiceTests.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/25/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class BTLEPlusSerialServiceTests : XCTestCase {
	
	func testWindowSizeMax() {
		let s = BTLEPlusSerialServiceController(withRunMode: .Central)
		s.windowSize = BTLEPlusSerialServiceMaxWindowSize + 1
		assert(s.windowSize == BTLEPlusSerialServiceMaxWindowSize)
	}
}