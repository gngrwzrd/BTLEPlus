//
//  OfferTurnTests.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/14/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import XCTest
@testable import BTLEPlus

class OfferTurnTests : BTLEPlusSerialServiceControllerBaseTests {
	
	override func setUp() {
		super.setUp()
		testingExpectedMessages = true
		//                   p         c    p         c         p
		expectedMessages = [.PeerInfo,.Ack,.TakeTurn,.TakeTurn,.Ack]
	}
	
	func testDefaultOfferTurn() {
		centralController?.resume()
		periphController?.resume()
		periphController?.offerTurnInterval = UInt64( Double(NSEC_PER_SEC) * 0.01)
		while(!done) {}
	}
}
