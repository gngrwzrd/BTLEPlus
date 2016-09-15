//
//  WaitTests.swift
//  BTLEPlus
//
//  Created by Aaron Smith on 9/14/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation

import XCTest
@testable import BTLEPlus

class NewMessageTests : BTLEPlusSerialServiceControllerBaseTests {
	
	var expectedMessages:[BTLEPlusSerialServiceProtocolMessageType] = [.PeerInfo,.Ack,.TakeTurn,.Ack,.NewMessage,.Ack,.Data,.EndMessage,.Ack]
	var done:Bool = false
	
	override func serialServiceController(controller: BTLEPlusSerialServiceController, wantsToSendData data: NSData) {
		
		let message = BTLEPlusSerialServiceProtocolMessage(withData: data)
		print("hooked data", message?.protocolType.rawValue)
		data.bleplus_base16EncodedString(uppercase: true)
		
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
	
	func testNewMessage() {
		centralController?.resume()
		periphController?.resume()
		periphController?.mtu = 155
		periphController?.offerTurnInterval = UInt64( Double(NSEC_PER_SEC) * 1)
		
		//wait for peer info exchange.
		sleep(1)
		periphController?.offerTurnInterval = UInt64( Double(NSEC_PER_SEC) * 100) //shut off turns just for test purposes.
		
		let s = "148E4241-8524-4813-B55F-6BBA94C4EB70"
		let d = s.dataUsingEncoding(NSUTF8StringEncoding)
		let message = BTLEPlusSerialServiceMessage(withMessageType: 0, messageId: 0, data: d!)
		centralController?.send(message!)
		
		while(!done){}
	}
	
}
