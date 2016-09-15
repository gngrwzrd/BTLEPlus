//
//  PeerInfoTests.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/14/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class PeerInfoTests : BTLEPlusSerialServiceControllerBaseTests {
	
	func testPeerInfo() {
		centralController?.resume()
		periphController?.resume()
		sleep(1)
		assert(centralController?.mtu == 32)
		assert(centralController?.windowSize == 64)
	}
	
	func testPeerInfo_OutOfOrder() {
		periphController?.resume()
		centralController?.resume()
		sleep(1)
		assert(centralController?.mtu == 32)
		assert(centralController?.windowSize == 64)
	}
	
}
