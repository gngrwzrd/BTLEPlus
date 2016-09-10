//
//  ViewController.swift
//  BLEPlusTestClientIOS
//
//  Created by Aaron Smith on 8/30/16.
//  Copyright © 2016 gngrwzrd. All rights reserved.
//

import UIKit
import CoreBluetooth
import BTLEPlusIOS

class ViewController: UIViewController, BLECentralManagerDelegate {
	
	var bleManager:BLECentralManager!
	var myPeripheral:TestPeripheralClient?
	
	override func viewDidLoad() {
		super.viewDidLoad()
		bleManager = BLECentralManager(withDelegate: self)
		bleManager.shouldRetrieveKnownPeripherals = false
		let prototype = TestPeripheralClient()
		bleManager.registerPeripheralPrototype(prototype)
	}
	
	func bleCentralManagerDidTurnOnBluetooth(manager: BLECentralManager) {
		bleManager.startScanning([TestPeripheralClient.ScanForUUID])
	}
	
	func bleCentralManagerDidDiscoverPeripheral(manager: BLECentralManager, peripheral: BLEPeripheral) {
		if let t = peripheral as? TestPeripheralClient {
			bleManager.connect(t)
		}
	}
	
	func blePeripheralConnected(manager:BLECentralManager,peripheral:BLEPeripheral) {
		print("connected")
	}
	
	func blePeripheralDisconnected(manager: BLECentralManager, peripheral: BLEPeripheral) {
		print("disconnected");
	}
	
	func blePeripheralIsReady(manager: BLECentralManager, peripheral: BLEPeripheral) {
		if let p = peripheral as? TestPeripheralClient {
			myPeripheral = p
		}
	}
	
	@IBAction func sendHelloWorld() {
		myPeripheral?.sendHelloWorld()
	}
	
	@IBAction func sendLipsum() {
		myPeripheral?.sendLipsum()
	}
	
	@IBAction func sendImage() {
		myPeripheral?.sendImage()
	}
	
	@IBAction func sendHelloWorldRequest() {
		myPeripheral?.sendHelloWorldRequest()
	}
}

