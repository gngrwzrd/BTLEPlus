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

public class TestPeripheralClient : BLEPeripheral, BLEPlusSerialServiceControllerDelegate {
	
	public static let ScanForUUID:CBUUID = CBUUID(string:"6DC4B345-635C-4690-B51D-0D358D32D5EF")
	var controller:BLEPlusSerialServiceController?
	var channel:CBCharacteristic?
	
	override public init() {
		super.init()
		controller = BLEPlusSerialServiceController(withMode: .Central)
		controller?.delegate = self
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
		controller?.pause()
	}
	
	override public func deviceIsReady() {
		super.deviceIsReady()
		controller?.resume()
	}
	
	public func serialServiceController(controller: BLEPlusSerialServiceController, wantsToSendData: NSData) {
		self.cbPeripheral?.writeValue(wantsToSendData, forCharacteristic: self.channel!, type: .WithResponse)
	}
	
	public func serialServiceController(controller: BLEPlusSerialServiceController, sentMessage message: BLEPlusSerialServiceMessage) {
		print("sent message ", message.messageType)
	}
	
	func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
		if characteristic == channel {
			if let data = characteristic.value {
				controller?.receivedData(data)
			} else {
				print("missing data?")
				print(characteristic.value)
			}
		}
	}
	
	func peripheral(peripheral: CBPeripheral, didWriteValueForDescriptor descriptor: CBDescriptor, error: NSError?) {
		print(error)
	}
	
}
