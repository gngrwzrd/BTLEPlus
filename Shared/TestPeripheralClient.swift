//
//  MyPeripheralClient.swift
//  BLEPlusTestClientIOS
//
//  Created by Aaron Smith on 8/30/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation
import CoreBluetooth

#if os(iOS)
@testable import BTLEPlusIOS
#elseif os(OSX)
@testable import BTLEPlus
#endif

public class TestPeripheralClient : BTLEPlusPeripheral, BTLEPlusSerialServiceControllerDelegate {
	
	public static let ScanForUUID:CBUUID = CBUUID(string:"6DC4B345-635C-4690-B51D-0D358D32D5EF")
	var serialController:BTLEPlusSerialServiceController!
	var channel:CBCharacteristic?
	var messageIdCounter:BTLEPlusSerialServiceMessageId_Type = 0
	
	override public init() {
		super.init()
		serialController = BTLEPlusSerialServiceController(withRunMode: .Central)
		serialController.delegate = self
	}
	
	override public func copy()  -> AnyObject {
		let copy = TestPeripheralClient()
		return copy
	}
	
	override public func respondsToAdvertisementData(advertisementData: BTLEAdvertisementData) -> Bool {
		if let services = advertisementData.serviceUUIDS {
			if services.contains( TestPeripheralClient.ScanForUUID ) {
				return true
			}
		}
		return false
	}
	
	override public func onSubscribeComplete() {
		peripheralReady = true
		super.onSubscribeComplete()
	}
	
	override public var canBeRemovedFromManager: Bool {
		get {
			return false
		} set(new) {
			super.canBeRemovedFromManager = new
		}
	}
	
	override public func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
		super.peripheral(peripheral, didUpdateNotificationStateForCharacteristic: characteristic, error: error)
		channel = characteristic
	}
	
	override public func onDisconnected() {
		super.onDisconnected()
		serialController.pause()
	}
	
	override public func onPeripheralReady() {
		super.onPeripheralReady()
		serialController.resume()
	}
	
	func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
		if characteristic == channel {
			if let data = characteristic.value {
				serialController.receive(data)
			} else {
				print("missing data?")
				print(characteristic.value)
			}
		}
	}
	
	func peripheral(peripheral: CBPeripheral, didWriteValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
		print(error)
	}
	
	public func serialServiceController(controller: BTLEPlusSerialServiceController, wantsToSendData: NSData) {
		self.cbPeripheral?.writeValue(wantsToSendData, forCharacteristic: self.channel!, type: .WithResponse)
	}
	
	public func serialServiceController(controller: BTLEPlusSerialServiceController, sentMessage message: BTLEPlusSerialServiceMessage) {
		print("sent message ", message.messageType)
	}
	
	public func serialServiceController(controller: BTLEPlusSerialServiceController, receivedMessage message: BTLEPlusSerialServiceMessage) {
		if message.messageType == HelloWorldRequest {
			receivedHelloWorldRequest(message)
		}
		
		if message.messageType == HelloWorldResponse {
			receivedHelloWorldResponse(message)
		}
	}
	
	func receivedHelloWorldResponse(message:BTLEPlusSerialServiceMessage) {
		let s = String(data:message.data!, encoding: NSUTF8StringEncoding)
		print("received hello world response")
		print(s)
	}
	
	func receivedHelloWorldRequest(message:BTLEPlusSerialServiceMessage) {
		print("received hello world request")
		let s = String(data:message.data!, encoding:NSUTF8StringEncoding)
		print(s)
		let d = "Goodbye World".dataUsingEncoding(NSUTF8StringEncoding)
		let response = BTLEPlusSerialServiceMessage(withMessageType: HelloWorldResponse, messageId: message.messageId, data: d!)
		serialController.send(response!)
	}
	
	func getMessageId() -> BTLEPlusSerialServiceMessageId_Type {
		if messageIdCounter == BTLEPlusSerialServiceMaxMessageId {
			messageIdCounter = 0
			return messageIdCounter
		}
		messageIdCounter = messageIdCounter + 1
		return messageIdCounter
	}
	
	func sendHelloWorld() {
		let s = "Hello World"
		let d = s.dataUsingEncoding(NSUTF8StringEncoding)
		let message = BTLEPlusSerialServiceMessage(withMessageType:1, messageId: 1, data: d!)
		serialController.send(message!)
	}
	
	func sendLipsum() {
		let s = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
		let d = s.dataUsingEncoding(NSUTF8StringEncoding)
		let message = BTLEPlusSerialServiceMessage(withMessageType: 3, messageId: 2, data: d!)
		serialController.send(message!)
	}
	
	func sendImage() {
		let fileURL = NSBundle.mainBundle().URLForResource("IMG_0123", withExtension: "PNG")
		let message = BTLEPlusSerialServiceMessage(withMessageType: 11, messageId: 2, fileURL: fileURL!)
		serialController.send(message!)
	}
	
	func sendHelloWorldRequest() {
		let s = "Hello World"
		let d = s.dataUsingEncoding(NSUTF8StringEncoding)
		let message = BTLEPlusSerialServiceMessage(withMessageType:HelloWorldRequest, messageId: getMessageId(), data: d!)
		serialController.send(message!)
	}
}
