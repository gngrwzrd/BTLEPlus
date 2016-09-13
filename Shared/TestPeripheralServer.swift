//
//  TestPeripheral.swift
//  BLEPlusTestServer
//
//  Created by Aaron Smith on 8/31/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import Foundation
import CoreBluetooth

#if os(iOS)
import BLEPlusIOS
#elseif os(OSX)
import BTLEPlus
#endif

public class TestPeripheralServer : NSObject, CBPeripheralManagerDelegate, BTLEPlusSerialServiceControllerDelegate {
	
	public static let ServiceUUID = CBUUID(string: "6DC4B345-635C-4690-B51D-0D358D32D5EF")
	public static let CharacteristicUUID = CBUUID(string: "CF8F353A-420C-423D-BEE8-BA36499335DF")
	
	var controller:BTLEPlusSerialServiceController!
	var messageIdCounter:BTLEPlusSerialServiceMessageId_Type = 0
	var testPairing:Bool = false
	var pmanager:CBPeripheralManager!
	var channel:CBMutableCharacteristic!
	var service:CBMutableService!
	
	override public init() {
		super.init()
		setupBLE()
		setupBLEPlus()
	}
	
	func setupBLE() {
		pmanager = CBPeripheralManager(delegate: self, queue: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0))
	}
	
	func setupBLEPlus() {
		controller = BTLEPlusSerialServiceController(withRunMode: .Peripheral)
		controller.delegate = self
	}
	
	func startAdvertising() {
		service = CBMutableService(type: TestPeripheralServer.ServiceUUID, primary: true)
		let props = CBCharacteristicProperties.Read.rawValue | CBCharacteristicProperties.Write.rawValue | CBCharacteristicProperties.WriteWithoutResponse.rawValue | CBCharacteristicProperties.NotifyEncryptionRequired.rawValue
		let perms = CBAttributePermissions.WriteEncryptionRequired.rawValue | CBAttributePermissions.ReadEncryptionRequired.rawValue
		let props2 = CBCharacteristicProperties.init(rawValue: props)
		let perms2 = CBAttributePermissions.init(rawValue: perms)
		
		var test = CBAttributePermissions()
		test.set(.ReadEncryptionRequired, on: true)
		test.set(.WriteEncryptionRequired, on: true)
		
//		var test = CBAttributePermissions()
//		test.setPermission(.ReadEncryptionRequired, on: true)
//		test.setPermission(.WriteEncryptionRequired, on: true)

//		let test = CBMutableCharacteristic(type: TestPeripheralServer.CharacteristicUUID, properties: .Read, value: nil, permissions: .ReadEncryptionRequired)
//		test.setProperty(.Read, on: on)
//		test.setProperty(.Write, on: on)
//		test.setProperty(.WriteWithoutResponse, on: on)
		
		channel = CBMutableCharacteristic(type: TestPeripheralServer.CharacteristicUUID, properties: props2, value: nil, permissions: perms2)
		service.characteristics = [channel]
		pmanager.addService(service)
		let ad = BTLEAdvertisementData()
		ad.serviceUUIDS = [service.UUID!]
		ad.localName = "BLEPlusTestServer"
		pmanager.startAdvertising(ad.discoveredData)
	}
	
	public func peripheralManagerDidUpdateState(peripheral: CBPeripheralManager) {
		switch(peripheral.state) {
		case .PoweredOn:
			startAdvertising()
		default:
			break
		}
	}
	
	public func peripheralManagerDidStartAdvertising(peripheral: CBPeripheralManager, error: NSError?) {
		print(error)
	}
	
	public func peripheralManagerIsReadyToUpdateSubscribers(peripheral: CBPeripheralManager) {
		controller?.resume()
	}
	
	public func peripheralManager(peripheral: CBPeripheralManager, didReceiveWriteRequests requests: [CBATTRequest]) {
		print("server: received write request")
		for request in requests {
			if testPairing {
				pmanager.respondToRequest(request, withResult: CBATTError.InsufficientAuthentication)
			} else {
				if request.characteristic == channel {
					controller.receive(request.value!)
					pmanager.respondToRequest(request, withResult: CBATTError.Success)
				} else {
					pmanager.respondToRequest(request, withResult: CBATTError.Success)
				}
			}
		}
	}
	
	public func peripheralManager(peripheral: CBPeripheralManager, didReceiveReadRequest request: CBATTRequest) {
		print("server: received read request");
		if testPairing {
			pmanager.respondToRequest(request, withResult: CBATTError.InsufficientAuthentication)
		} else {
			pmanager.respondToRequest(request, withResult: CBATTError.Success)
		}
	}
	
	public func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didSubscribeToCharacteristic characteristic: CBCharacteristic) {
		print("server: central subscribed")
		
		print("maxValue: ",central.maximumUpdateValueLength)
		controller.mtu = BTLEPlusSerialServiceMTU_Type(central.maximumUpdateValueLength)
		
		if characteristic == channel {
			controller.resume()
		}
	}
	
	public func peripheralManager(peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFromCharacteristic characteristic: CBCharacteristic) {
		print("server: central unsubscribed")
		if characteristic == channel {
			controller.pause()
		}
	}
	
	public func serialServiceController(controller: BTLEPlusSerialServiceController, wantsToSendData data: NSData) {
		let didSend = self.pmanager.updateValue(data, forCharacteristic: self.channel, onSubscribedCentrals: nil)
		if !didSend {
			print("! did send:")
			controller.pause()
		}
	}
	
	public func serialServiceController(controller: BTLEPlusSerialServiceController, receivedMessage message: BTLEPlusSerialServiceMessage) {
		print("received complete message:", message.messageType)
		
		if message.messageType == HelloWorldRequest {
			receivedHelloWorldRequest(message)
		}
		
		if message.messageType == HelloWorldResponse {
			recievedHelloWorldResponse(message)
		}
		
		if message.messageType < 10 {
			let string = String.init(data: message.data!, encoding: NSUTF8StringEncoding)
			print(string)
		}
		
		if message.messageType == 11 {
			print("received image")
			print(message.fileURL)
		}
	}
	
	public func serialServiceController(controller: BTLEPlusSerialServiceController, sentMessage message: BTLEPlusSerialServiceMessage) {
		print("sent message:",message.messageType)
	}
	
	public func serialServiceController(controller: BTLEPlusSerialServiceController, droppedMessageFromReset message: BTLEPlusSerialServiceMessage) {
		print("dropped message",message.messageType)
	}
	
	public func serialServiceController(controller: BTLEPlusSerialServiceController, droppedMessageFromPeerReset message: BTLEPlusSerialServiceMessage) {
		print("dropped message",message.messageType)
	}
	
	func getMessageId() -> BTLEPlusSerialServiceMessageId_Type {
		if messageIdCounter == BTLEPlusSerialServiceMaxMessageId {
			messageIdCounter = 0
			return messageIdCounter
		}
		messageIdCounter = messageIdCounter + 1
		return messageIdCounter
	}
	
	func receivedHelloWorldRequest(request:BTLEPlusSerialServiceMessage) {
		let s = String(data: request.data!, encoding: NSUTF8StringEncoding)
		print(s)
		let v = "Goodbye World"
		let d = v.dataUsingEncoding(NSUTF8StringEncoding)
		let response = BTLEPlusSerialServiceMessage(withMessageType: HelloWorldResponse, messageId: request.messageId, data: d!)
		controller.send(response!)
	}
	
	func recievedHelloWorldResponse(request:BTLEPlusSerialServiceMessage) {
		let s = String(data:request.data!, encoding: NSUTF8StringEncoding)
		print("received hello world response:",s)
	}
	
	func sendHelloWorldRequest() {
		let s = "Hello World"
		let d = s.dataUsingEncoding(NSUTF8StringEncoding)
		let message = BTLEPlusSerialServiceMessage(withMessageType:HelloWorldRequest, messageId: getMessageId(), data: d!)
		controller.send(message!)
	}
}
	