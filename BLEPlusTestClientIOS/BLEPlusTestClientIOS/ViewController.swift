//
//  ViewController.swift
//  BLEPlusTestClientIOS
//
//  Created by Aaron Smith on 8/30/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import UIKit
import CoreBluetooth
import BLEPlusIOS

class ViewController: UIViewController, BLECentralManagerDelegate {
	
	var bleManager:BLECentralManager!
	var myPeripheral:TestPeripheralClient?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		bleManager = BLECentralManager(withDelegate: self)
		bleManager.shouldRetrieveKnownDevices = false
		let prototype = TestPeripheralClient()
		bleManager.registerDevicePrototype(prototype)
	}
	
	func bleCentralManagerDidTurnOnBluetooth(manager: BLECentralManager) {
		bleManager.startScanning([TestPeripheralClient.ScanForUUID])
	}
	
	func bleCentralManagerDidDiscoverDevice(manager: BLECentralManager, device: BLEPeripheral) {
		if let t = device as? TestPeripheralClient {
			bleManager.connect(t)
		}
	}
	
	func blePeripheralConnected(manager:BLECentralManager,device:BLEPeripheral) {
		print("connected")
	}
	
	func blePeripheralDisconnected(manager: BLECentralManager, device: BLEPeripheral) {
		print("disconnected");
	}
	
	func blePeripheralIsReady(manager: BLECentralManager, device: BLEPeripheral) {
		if let p = device as? TestPeripheralClient {
			myPeripheral = p
		}
	}
	
	@IBAction func sendHelloWorld() {
		let s = "Hello World"
		let d = s.dataUsingEncoding(NSUTF8StringEncoding)
		let message = BLEPlusSerialServiceMessage(withType:1, messageId: 1, data: d!)
		myPeripheral?.controller?.send(message!)
	}
	
	@IBAction func sendLipsum() {
		let s = "Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum."
		let d = s.dataUsingEncoding(NSUTF8StringEncoding)
		let message = BLEPlusSerialServiceMessage(withType: 3, messageId: 2, data: d!)
		myPeripheral?.controller?.sendQueue?.append(message!)
		
		let message2 = BLEPlusSerialServiceMessage(withType: 3, messageId: 2, data: d!)
		myPeripheral?.controller?.send(message2!)
	}
	
	@IBAction func sendImage() {
		let fileURL = NSBundle.mainBundle().URLForResource("IMG_0123", withExtension: "PNG")
		let message = BLEPlusSerialServiceMessage(withType: 11, messageId: 2, fileURL: fileURL!)
		myPeripheral?.controller?.send(message!)
	}
}

