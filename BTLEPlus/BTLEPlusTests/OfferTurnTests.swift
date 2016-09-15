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
	
	var hasSentTakeTurn:Bool = false
	var expectedMessages:[BTLEPlusSerialServiceProtocolMessageType] = [.PeerInfo,.Ack,.TakeTurn,.TakeTurn,.Ack]
	var done:Bool = false
	
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
		centralController?.offerTurnInterval = UInt64( Double(NSEC_PER_SEC) * 0.2)
		periphController?.resume()
		periphController?.offerTurnInterval = UInt64( Double(NSEC_PER_SEC) * 0.2)
		while(!done) {}
	}
}
