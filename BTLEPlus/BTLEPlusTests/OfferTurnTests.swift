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
		expectedMessages = [.PeerInfo,.Ack,.TakeTurn,.TakeTurn,.Ack]
	}
	
	override func serialServiceController(controller: BTLEPlusSerialServiceController, wantsToSendData data: NSData) {
		
		let message = BTLEPlusSerialServiceProtocolMessage(withData: data)
		if expectedMessages.count > 0 {
			assert( message?.protocolType == expectedMessages[0] )
			expectedMessages.removeAtIndex(0)
			if expectedMessages.count < 1 {
				done = true
				return
			}
		}
		
		super.serialServiceController(controller, wantsToSendData: data)
	}
	
	func testDefaultOfferTurn() {
		centralController?.resume()
		periphController?.resume()
		periphController?.offerTurnInterval = UInt64( Double(NSEC_PER_SEC) * 0.01)
		while(!done) {}
	}
}
