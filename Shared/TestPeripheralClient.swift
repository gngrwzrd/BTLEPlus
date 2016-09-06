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
import BLEPlusIOS
#elseif os(OSX)
import BLEPlus
#endif

public class TestPeripheralClient : BLEPeripheral, BLEPlusSerialServiceControllerDelegate, BLEPlusRequestResponseControllerDelegate {
	
	public static let ScanForUUID:CBUUID = CBUUID(string:"6DC4B345-635C-4690-B51D-0D358D32D5EF")
	var serialController:BLEPlusSerialServiceController!
	var channel:CBCharacteristic?
	var messageIdCounter:BLEPLusSerialServiceMessageId_Type = 0
	
	override public init() {
		super.init()
		serialController = BLEPlusSerialServiceController(withMode: .Central)
		serialController.delegate = self
	}
	
	override public func copy()  -> AnyObject {
		let copy = TestPeripheralClient()
		return copy
	}
	
	override public func respondsToAdvertisementData(advertisementData: BLEAdvertisementData) -> Bool {
		if let services = advertisementData.serviceUUIDS {
			if services.contains( TestPeripheralClient.ScanForUUID ) {
				return true
			}
		}
		return false
	}
	
	override public func shouldReconnectOnDisconnect() -> Bool {
		return true
	}
	
	override public func subscribingFinished() {
		deviceReady = true
		super.subscribingFinished()
	}
	
	override public func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
		super.peripheral(peripheral, didUpdateNotificationStateForCharacteristic: characteristic, error: error)
		channel = characteristic
	}
	
	override public func disconnected() {
		super.disconnected()
		serialController.pause()
	}
	
	override public func deviceIsReady() {
		super.deviceIsReady()
		serialController.resume()
	}
	
	func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
		if characteristic == channel {
			if let data = characteristic.value {
				serialController.receivedData(data)
			} else {
				print("missing data?")
				print(characteristic.value)
			}
		}
	}
	
	func peripheral(peripheral: CBPeripheral, didWriteValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
		print(error)
	}
	
	public func serialServiceController(controller: BLEPlusSerialServiceController, wantsToSendData: NSData) {
		self.cbPeripheral?.writeValue(wantsToSendData, forCharacteristic: self.channel!, type: .WithResponse)
	}
	
	public func serialServiceController(controller: BLEPlusSerialServiceController, sentMessage message: BLEPlusSerialServiceMessage) {
		print("sent message ", message.messageType)
	}
	
	public func serialServiceController(controller: BLEPlusSerialServiceController, receivedMessage message: BLEPlusSerialServiceMessage) {
		if message.messageType == HelloWorldRequest {
			receivedHelloWorldRequest(message)
		}
		
		if message.messageType == HelloWorldResponse {
			receivedHelloWorldResponse(message)
		}
	}
	
	func receivedHelloWorldResponse(message:BLEPlusSerialServiceMessage) {
		let s = String(data:message.data!, encoding: NSUTF8StringEncoding)
		print("received hello world response")
		print(s)
	}
	
	func receivedHelloWorldRequest(message:BLEPlusSerialServiceMessage) {
		print("received hello world request")
		let s = String(data:message.data!, encoding:NSUTF8StringEncoding)
		print(s)
		let d = "Goodbye World".dataUsingEncoding(NSUTF8StringEncoding)
		let response = BLEPlusSerialServiceMessage(withMessageType: HelloWorldResponse, messageId: message.messageId, data: d!)
		serialController.send(response!)
	}
	
	func getMessageId() -> BLEPLusSerialServiceMessageId_Type {
		if messageIdCounter == BLEPlusSerialServiceMaxMessageId {
			messageIdCounter = 0
			return messageIdCounter
		}
		messageIdCounter = messageIdCounter + 1
		return messageIdCounter
	}
	
	func sendHelloWorld() {
		let s = "Hello World"
		let d = s.dataUsingEncoding(NSUTF8StringEncoding)
		let message = BLEPlusSerialServiceMessage(withMessageType:1, messageId: 1, data: d!)
		serialController.send(message!)
	}
	
	func sendLipsum() {
		let s = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
		let d = s.dataUsingEncoding(NSUTF8StringEncoding)
		let message = BLEPlusSerialServiceMessage(withMessageType: 3, messageId: 2, data: d!)
		serialController.sendQueue?.append(message!)
	}
	
	func sendImage() {
		let fileURL = NSBundle.mainBundle().URLForResource("IMG_0123", withExtension: "PNG")
		let message = BLEPlusSerialServiceMessage(withMessageType: 11, messageId: 2, fileURL: fileURL!)
		serialController.send(message!)
	}
	
	func sendHelloWorldRequest() {
		let s = "Hello World"
		let d = s.dataUsingEncoding(NSUTF8StringEncoding)
		let message = BLEPlusSerialServiceMessage(withMessageType:HelloWorldRequest, messageId: getMessageId(), data: d!)
		serialController.send(message!)
	}
}
