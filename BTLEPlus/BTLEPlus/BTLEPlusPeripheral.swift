
import CoreBluetooth

/**
The BTLEPlusPeripheral object is a generic peripheral that allows you to customize
the connection and discovery process before it's considered ready to use.

## Peripheral Setup

Each peripheral goes through this setup process before it's considered ready
to use. And must go through the same setup process if it's disconnected and
then reconnected.

Each step in the setup process has retries and timeouts you can customize.
If something fails or times-out it will try the same step up to a specified
max attemps.

#### Connect Step

This is the first step in the process and is handled by a BTLECentralManager.
After your central discovers peripherals, you connect to the desired peripheral with
_myBTLECentralManager.connect(peripheral:)_.

#### Discovery Step

This is the second step in the process. It includes _discovering services_, _discovering included services_,
_discovering characteristics_ and _discovering descriptors_.

#### Subscribe Step

This is the third step in the process. It includes _subscribing to any characteristics that support notify_.

#### Additional Setup Step

This is an optional step in which you can include additional steps as part of the
peripheral setup process. You can override requiresAdditionalSetup() and
performAdditionalSetup() to add your custom setup into the setup process. You must
call peripheralIsReady() once your additional setup is complete.

#### Ready Step

This is the last step and the peripheral is considered ready. It's up
to you to implement communication or specialized behavior with the peripheral after
this point.

## Peripheral Prototypes

Peripheral objects aren't created by you and used directly, instead you create
a prototype object, and register it with a BTLECentralManager.

When a BTLECentralManager discovers peripherals, it asks each registered BTLEPlusPeripheral
prototype if it knows how to respond to the advertised services. If the peripheral
understands the advertisement data, it's instantiated and considered discovered.

You can override respondsToAdvertisementData(), which tells the central manager if it should
instantiate your peripheral and consider it discovered.

## Responding to Advertisement Data

````
class MyPeripheral : BTLEPlusPeripheral {
	//override and decide if your peripheral understands the advertised data.
	override public func respondsToAdvertisementData(data:BTLEAdvertisementData) -> Bool {
		//inspect advertisement data here.
		return true or false.
	}
	//override and return a new instance of MyPeripheral. This is required.
	override public func copy() -> AnyObject {
		return MyPeripheral()
	}
}
````

##### Multiple Advertisement Packets

At times Core Bluetooth will receive advertisement data in multiple parts. When this happens
the advertisement data for a peripheral is collected using a BTLEAdvertisementData
object. Your peripheral prototype will be asked each time with the collected data if it
responds to the advertisement data. This ensures you eventually get all of the advertisement
data to properly decide if your prototype understands the advertised services.

*/
@objc public class BTLEPlusPeripheral : NSObject, CBPeripheralDelegate {
	
	//MARK: CBPeripheral
	
	/// The CBPeripheral this class monitors and manages.
	var cbPeripheral:CBPeripheral?
	
	/// Local peripheral name.
	public var name:String? {
		return cbPeripheral?.name
	}
	
	/// Called when the peripheral name updated.
	public func updatedName() {
		
	}
	
	/// Peripheral RSSI.
	public var RSSI: NSNumber? {
		get {
			return _RSSI
		} set(new) {
			_RSSI = new
		}
	}
	private var _RSSI:NSNumber? = nil
	
	/// Called when the peripheral RSSI updated.
	public func updatedRSSI() {
		
	}
	
	/// Called when RSSI update received an error.
	public func updatedRSSIReceivedError(error:NSError?) {
		
	}
	
	/// Peripheral UUID.
	public var UUID:NSUUID? {
		if let peripheral = cbPeripheral {
			return peripheral.identifier
		}
		return nil
	}
	
	//MARK: - Configuration
	
	/// A custom tag to identify the peripheral.
	public var tag:Int = 0
	
	/// A custom organization identifier for this peripheral.
	public var organization:String?
	
	/// Whether or not this peripheral should be removed from it's BTLECentralManager.
	/// This is queried when a peripheral disconnects.
	///
	/// If false, the peripheral will remain in a disconnected state
	/// within it's BTLECentralManager.
	///
	/// If true it's removed from it's BTLEPlusCentralManager and you'd have
	/// to scan for the peripheral again.
	///
	/// Default is true.
	///
	/// This is an overrideable getter / setter.
	public var canBeRemovedFromManager:Bool {
		get {
			return _canBeRemovedFromManager
		} set(new) {
			_canBeRemovedFromManager = new
		}
	}
	private var _canBeRemovedFromManager = true
	
	/// Whether to reconnect when the peripheral is disconnected.
	///
	/// Default is true.
	///
	/// This is an overrideable getter / setter.
	public var shouldReconnectOnDisconnect:Bool {
		get {
			return _reconnectOnDisconnect
		} set(new) {
			_reconnectOnDisconnect = new
		}
	}
	private var _reconnectOnDisconnect = true
	
	//MARK: Timeouts and Retries
	
	/// The maximum tries for a step in the setup process.
	public var maxAttempts = 3
	
	/// The timeout length before retrying the current step.
	public var attemptTimeoutLength:NSTimeInterval = 5
	
	/// The BTLEPlusCentralManager that currently is managing this peripheral.
	weak var btleCentralManager:BTLEPlusCentralManager?
	
	/// The CBCentralManager for this peripheral.
	weak var btCentralManager:CBCentralManager?
	
	/// Utility variable for all retry logic that keeps track of how many more attempts are allowed.
	var attempts = 0
	
	/// Utility variable for any timeout required which would trigger another attempt.
	var timeout:NSTimer?
	
	/// Whether or not the peripheral is going through it's setup step before it's considered ready.
	/// This flag is needed in order to allow subclasses to override peripheral delegate methods properly.
	var isInSetup = false
	
	/// The number of services whos characteristics are being discovered.
	var discoveringCharacteristics = 0
	
	/// The number of characteristics whos descriptors are being discovered.
	var discoveringDescriptors = 0
	
	/// The number of services who's included sevices are being discovered.
	var discoveringIncludedServices = 0
	
	/// The number of characteristics who's setNotify value is being subscribed to.
	var setNotifyCount = 0
	
	/// An error object to pass to listeners when the setup process completely fails.
	var setupOutgoingError:NSError?
	
	/// The last error received from a disconnect.
	var lastDisconnectError:NSError?
	
	//MARK: Advertisement Data
	
	/// Advertisement data for the peripheral.
	public var advertisementData:BTLEAdvertisementData? {
		get {
			return _advertisementData
		} set(newAdvertisementData) {
			_advertisementData = newAdvertisementData
		}
	}
	var _advertisementData:BTLEAdvertisementData?
	
	/**
	Whether or not your peripheral can uderstand the advertised data from
	another peripheral.
	
	Override this and implement logic that decides if your peripheral understands
	advertised data.
	
	- parameter advertisementData: The advertised data.
	
	- returns: Bool
	*/
	public func respondsToAdvertisementData(advertisementData:BTLEAdvertisementData) -> Bool {
		print("override respondsToAdvertisementData")
		return false
	}
	
	/// Called when a peripheral receives more advertisement data. This can happen
	/// when peripheral discovery is running. Core Bluetooth may send multiple packets
	/// of advertisement data.
	func receivedMoreAdvertisementData(newData:BTLEAdvertisementData) {
		advertisementData?.append(newData)
		if peripheralReady {
			btleCentralManager?.saveKnownPeripheral(self, advertisementData: advertisementData)
		}
	}
	
	//MARK: Connectivity
	
	/// When a peripheral was retrieved from Core Bluetooth.
	///
	/// If the discovered peripheral is not connected, it will connect for you.
	///
	/// If the discovered peripheral is already connected it will go through
	/// the setup process.
	public func wasRetrieved() {
		if cbPeripheral?.state == CBPeripheralState.Disconnected {
			connect()
		}
		if cbPeripheral?.state == CBPeripheralState.Connected {
			discoverServices()
		}
	}
	
	/// You can override this to be notified of when a peripheral was discovered.
	///
	/// It's also called when a peripheral is _retrieved_ from Core Bluetooth
	/// and considered discovered.
	public func wasDiscovered() {
		btleCentralManager?.delegate?.btleCentralManagerDidDiscoverPeripheral?(btleCentralManager!, peripheral: self)
	}
	
	/// This starts the connect process with Core Bluetooth.
	func connect() {
		if let peripheral = cbPeripheral {
			if peripheral.state == CBPeripheralState.Connecting || peripheral.state == CBPeripheralState.Connected {
				return
			}
		}
		attempts = maxAttempts
		lastDisconnectError = nil
		isInSetup = true
		retryConnect()
	}
	
	/// Called when peripheral is connected, but not yet ready to use.
	public func onConnected() {
		cbPeripheral?.delegate = self
		btleCentralManager?.delegate?.btlePeripheralConnected?(btleCentralManager!, peripheral: self)
		discoverServices()
	}
	
	/// This retries the connection after a connection timeout.
	func retryConnect() {
		attempts = attempts - 1
		if attempts < 1 {
			let userinfo = [NSLocalizedDescriptionKey:"Connect timed out."]
			setupOutgoingError = NSError(domain: "ble", code: 0, userInfo: userinfo)
			connectFailed()
			return
		}
		if let peripheral = self.cbPeripheral {
			peripheralReady = false
			startConnectTimeout()
			btCentralManager?.connectPeripheral(peripheral, options: nil)
		}
	}
	
	/// Starts the connection timeout
	func startConnectTimeout() {
		timeout?.invalidate()
		timeout = NSTimer.scheduledTimerWithTimeInterval(attemptTimeoutLength, target: self, selector: #selector(BTLEPlusPeripheral.connectTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	/// On connection timeout
	func connectTimeout(timer:NSTimer?) {
		if let peripheral = cbPeripheral {
			btCentralManager?.cancelPeripheralConnection(peripheral)
		}
		retryConnect()
	}
	
	/// When the central fails to connect and receives an error.
	func btCentralManagerReceivedConnectError(error:NSError?) {
		setupOutgoingError = error
		retryConnect()
	}
	
	/// When the central fails to connect but there was no error provided.
	func btManagerReceivedFatalConnect() {
		connectFailed()
	}
	
	/// Called after maxAttempts to connect failed.
	func connectFailed() {
		btleCentralManager?.delegate?.btlePeripheralFailedToConnect?(btleCentralManager!, peripheral: self, error: setupOutgoingError)
		disconnect()
		if canBeRemovedFromManager {
			btleCentralManager?.removePeripheral(self)
		}
	}
	
	/// Disconnect this peripheral.
	func disconnect() {
		if cbPeripheral?.state == CBPeripheralState.Disconnected {
			return
		}
		if let peripheral = cbPeripheral {
			btCentralManager?.cancelPeripheralConnection(peripheral)
		}
	}
	
	/// Called when the peripheral is disconnected.
	public func onDisconnected() {
		btleCentralManager?.delegate?.btlePeripheralDisconnected?(btleCentralManager!, peripheral: self)
		
		isInSetup = false
		cbPeripheral?.delegate = nil
		
		if shouldReconnectOnDisconnect {
			connect()
		}
		
		if !shouldReconnectOnDisconnect && canBeRemovedFromManager {
			btleCentralManager?.removePeripheral(self)
		}
	}
	
	/// When the BTLECentralManager receives a disconnect for this peripheral.
	func btCentralManagerReceivedDisconnect() {
		onDisconnected()
	}
	
	/// When the BTLECentralManager receives a disconnect for this peripheral and receives and error.
	func btCentralManagerReceivedDisconnectError(error:NSError?) {
		lastDisconnectError = error
		setupOutgoingError = error
		onDisconnected()
	}
	
	//MARK: Peripheral Ready
	
	/// Whether or not this peripheral is ready.
	/// 
	/// _isPeripheralReady()_ uses this value to query if the peripheral is ready.
	public var peripheralReady = false
	
	/// Returns whether the peripheral is considered ready.
	///
	/// You can override this to provide your own logic that decides of the
	/// peripheral is ready.
	///
	/// By default this returns the value of _peripheralReady_
	///
	/// - returns: Bool
	public func isPeripheralReady() -> Bool {
		return peripheralReady
	}
	
	/// When the peripheral is ready this is called.
	///
	/// You can also call this from your subclasses when you know your peripheral
	/// is ready to use.
	public func onPeripheralReady() {
		timeout?.invalidate()
		timeout = nil
		isInSetup = false
		btleCentralManager?.saveKnownPeripheral(self,advertisementData: advertisementData)
		btleCentralManager?.delegate?.btlePeripheralIsReady?(btleCentralManager!, peripheral: self)
	}
	
	/// Called when the discovery step is being retried.
	func retryingDiscoveryStep() {
		
	}
	
	/// Called when the subscribe step is being retried.
	func retryingSubscribeStep() {
		
	}
	
	/// Called when the discover step failed after max discover attempts has passed.
	func discoveryStepFailed() {
		disconnect()
		btleCentralManager?.delegate?.btlePeripheralSetupFailed?(btleCentralManager!, peripheral: self, error: setupOutgoingError)
	}
	
	/// Called when the subscribe step failed after max subscribe attempts has passed.
	func subscribeStepFailed() {
		disconnect()
		btleCentralManager?.delegate?.btlePeripheralSetupFailed?(btleCentralManager!, peripheral: self, error: setupOutgoingError)
	}
	
	//MARK: Service Discovery
	
	/**
	Override and decide which services you want discovered.
	
	Default is true.
	
	- parameter uuid: A service CBUUID.
	- returns: Whether or not to discover the service.
	*/
	public func shouldDiscoverService(uuid:CBUUID) -> Bool {
		return true
	}
	
	/// Starts the discover services step.
	func discoverServices() {
		var servicesToDiscover:[CBUUID] = []
		isInSetup = true
		
		//if we have uuid data from advertising data allow self to choose
		//which services to discover
		if let uuids = advertisementData?.serviceUUIDS {
			for uuid in uuids {
				if shouldDiscoverService(uuid) {
					servicesToDiscover.append(uuid)
				}
			}
		
		//we don't have any uuids from advertising data, just discover all.
		//this is from a peripheral being retrieved at startup which doesn't
		//include advertising data.
		} else {
			startTimeoutForDiscoverServices()
			cbPeripheral?.discoverServices(nil)
			return
		}
		
		if servicesToDiscover.count < 1 {
			startSubscribing()
			return
		}
		
		startTimeoutForDiscoverServices()
		cbPeripheral?.discoverServices(servicesToDiscover)
	}
	
	/// Starts the timeout for service discovery.
	func startTimeoutForDiscoverServices() {
		timeout?.invalidate()
		attempts = maxAttempts
		timeout = NSTimer.scheduledTimerWithTimeInterval(attemptTimeoutLength, target: self, selector: #selector(BTLEPlusPeripheral.discoverServicesTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	/// service discovery received an error
	func discoverServicesReceivedError(error:NSError?) {
		attempts = attempts - 1
		if attempts < 1 {
			setupOutgoingError = error
			discoveryStepFailed()
			return
		}
		discoverServicesIsRetrying()
		discoverServices()
	}
	
	/// service discovery timed out.
	func discoverServicesTimeout(timer:NSTimer?) {
		let userInfo = [NSLocalizedDescriptionKey:"Discover Services Timed Out"]
		let error = NSError(domain: "ble", code: 0, userInfo: userInfo)
		discoverServicesReceivedError(error)
	}
	
	/// service discovery is retrying.
	func discoverServicesIsRetrying() {
		retryingDiscoveryStep()
	}
	
	/// When services are invalidated, your peripheral goes through the setup process
	/// again to discover services, included services, characteristics and descriptors.
	public func servicesWereInvalidated() {
		peripheralReady = false
		discoverServices()
	}
	
	//MARK: Included Service Discovery
	
	/**
	Whether or not included services should be discovered.
	
	- returns: Bool
	*/
	public func shouldDiscoverIncludedServices() -> Bool {
		return false
	}
	
	/**
	Override to control which included services are discovered.
	
	- parameter service: The service who's included services should be discovered.
	
	- returns: Returning [CBUUID,] means specific services, [] means all included services,
	nil means don't discover any included services. Default is nil.
	*/
	public func discoverIncludedServicesForService(service:CBService?) -> [CBUUID]? {
		return nil
	}
	
	/// Starts the discovery of included services.
	func discoverIncludedServices() {
		isInSetup = true
		
		if !shouldDiscoverIncludedServices() {
			discoverCharacteristics()
			return
		}
		
		discoveringIncludedServices = 0
		var includedServicesToDiscover:[CBService:[CBUUID]] = [:]
		if let services = cbPeripheral?.services {
			
			for service in services {
				
				if let includedServices = discoverIncludedServicesForService(service) {
					discoveringIncludedServices = discoveringIncludedServices + 1
					includedServicesToDiscover[service] = includedServices
				}
			}
			
			if includedServicesToDiscover.count > 0 {
				startTimeoutForDiscoverIncludedServices()
			}
			
			for (service,uuids) in includedServicesToDiscover {
				if uuids.count > 0 {
					cbPeripheral?.discoverIncludedServices(uuids, forService: service)
				} else {
					cbPeripheral?.discoverIncludedServices(nil, forService: service)
				}
			}
		}
		
		if discoveringIncludedServices < 1 {
			discoverCharacteristics()
		}
	}
	
	/// Starts the timeout for discoverying included services
	func startTimeoutForDiscoverIncludedServices() {
		attempts = maxAttempts
		timeout = NSTimer.scheduledTimerWithTimeInterval(attemptTimeoutLength, target: self, selector: #selector(BTLEPlusPeripheral.discoverIncludedServicesTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	/// Timeout for included services discovery
	func discoverIncludedServicesTimeout(timer:NSTimer) {
		discoverIncludedServicesReceivedError(nil)
	}
	
	/// Discovering an included service received an error
	func discoverIncludedServicesReceivedError(error:NSError?) {
		attempts = attempts - 1
		if attempts < 1 {
			setupOutgoingError = error
			discoveryStepFailed()
			return
		}
		discoverIncludedServicesIsRetrying()
		discoverIncludedServices()
	}
	
	/// Called when discovering included services is retrying.
	func discoverIncludedServicesIsRetrying() {
		retryingDiscoveryStep()
	}
	
	//MARK: Characteristics Discovery
	
	/**
	Whether or not to discover characteristics.
	
	Default is true.
	
	- returns: Bool
	*/
	public func shouldDiscoverCharacteristics() -> Bool {
		return true
	}
	
	/**
	Override to control which characteristics are discovered.
	
	Default behavior is to discover all characteristics for a service.
	
	- parameter service: The service who's characteristics will be discovered.
	
	- returns: [CBUUID,] means specific characteristic, [] means all characteristics,
	nil means don't discover any characteristics for the service.
	*/
	public func discoverCharacteristicsForService(service:CBService?) -> [CBUUID]? {
		return []
	}
	
	/**
	Whether or not to discover characteristics for an included service of another service.
	
	- parameter service:         The root service.
	- parameter includedService: The included service.
	
	- returns: [CBUUID,] means specific characteristic, [] means all characteristics,
	nil means don't discover any characteristics for this service.
	*/
	public func discoverCharacteristicsForIncludedService(service:CBService?, includedService:CBService?) -> [CBUUID]? {
		return nil
	}
	
	/// Starts the discovery of characteristics.
	func discoverCharacteristics() {
		isInSetup = true
		
		if !shouldDiscoverCharacteristics() {
			startSubscribing()
			return
		}
		
		discoveringCharacteristics = 0
		var characteristicsToDiscover:[CBService:[CBUUID]] = [:]
		
		if let services = cbPeripheral?.services {
			for service in services {
				if let charsToDiscover = discoverCharacteristicsForService(service) {
					discoveringCharacteristics = discoveringCharacteristics + 1
					characteristicsToDiscover[service] = charsToDiscover
				}
				
				if let includedServices = service.includedServices {
					for includedService in includedServices {
						if let charsToDiscover = discoverCharacteristicsForIncludedService(service, includedService: includedService) {
							discoveringCharacteristics = discoveringCharacteristics + 1
							characteristicsToDiscover[includedService] = charsToDiscover
						}
					}
				}
			}
		}
		
		if characteristicsToDiscover.count > 0 {
			startTimeoutForDiscoverCharacteristics()
		}
		
		for (service,uuids) in characteristicsToDiscover {
			if uuids.count > 0 {
				cbPeripheral?.discoverCharacteristics(uuids, forService: service)
			} else {
				cbPeripheral?.discoverCharacteristics(nil, forService: service)
			}
		}
		
		if discoveringCharacteristics < 1 {
			startSubscribing()
		}
	}
	
	/// Starts the timeout for characteristic discovery.
	func startTimeoutForDiscoverCharacteristics() {
		attempts = maxAttempts
		timeout = NSTimer.scheduledTimerWithTimeInterval(attemptTimeoutLength, target: self, selector: #selector(BTLEPlusPeripheral.discoverCharacteristicsTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	/// Discovering characteristics timed out.
	func discoverCharacteristicsTimeout(timer:NSTimer) {
		discoverCharacteristicsReceivedError(nil)
	}
	
	/// Discover characteristics is retrying.
	func discoverCharacteristicsIsRetrying() {
		retryingDiscoveryStep()
	}
	
	/// Discovering characteristics received an error.
	func discoverCharacteristicsReceivedError(error:NSError?) {
		attempts = attempts - 1
		if attempts < 1 {
			setupOutgoingError = error
			discoveryStepFailed()
			return
		}
		discoverCharacteristicsIsRetrying()
		discoverCharacteristics()
	}
	
	//MARK: Descriptor Discovery
	
	/**
	Whether or not descriptors should be discovered.
	
	Default is false.
	
	- returns: Bool
	*/
	public func shouldDiscoverDescriptors() -> Bool {
		return false
	}
	
	/**
	Override to customize which descriptors are descovered.
	
	Default behavior is to not discover any descriptors.
	
	- parameter characteristic: The characteristic.
	- parameter service:        The service
	- returns: Bool
	*/
	public func shouldDiscoverDescriptorsForCharacteristic(characteristic:CBCharacteristic, service:CBService?) -> Bool {
		return false
	}
	
	/// Starts the descriptor discovery.
	func discoverDescriptors() {
		isInSetup = true
		
		if !shouldDiscoverDescriptors() {
			startSubscribing()
			return
		}
		
		if let services = cbPeripheral?.services {
			
			discoveringDescriptors = 0
			
			for service in services {
				if let chars = service.characteristics {
					for char in chars {
						if shouldDiscoverDescriptorsForCharacteristic(char, service: service) {
							discoveringDescriptors = discoveringDescriptors + chars.count
						}
					}
				}
			}
			
			for service in services {
				if let chars = service.characteristics {
					for char in chars {
						if shouldDiscoverDescriptorsForCharacteristic(char, service: service) {
							startTimeoutForDiscoverDescriptors()
							cbPeripheral?.discoverDescriptorsForCharacteristic(char)
						}
					}
				}
			}
			
			if discoveringDescriptors == 0 {
				startSubscribing()
			}
		}
	}
	
	/// Starts the timeout for descriptor discovery
	func startTimeoutForDiscoverDescriptors() {
		attempts = maxAttempts
		timeout = NSTimer.scheduledTimerWithTimeInterval(attemptTimeoutLength, target: self, selector: #selector(BTLEPlusPeripheral.discoverDescriptorsTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	/// Timeout of descriptor discovery
	func discoverDescriptorsTimeout(timer:NSTimer) {
		discoverDescriptorsReceivedError(nil)
	}
	
	/// Called when discovering a descriptor received an error
	func discoverDescriptorsReceivedError(error:NSError?) {
		attempts = attempts - 1
		if attempts < 1 {
			setupOutgoingError = error
			discoveryStepFailed()
			return
		}
		descriptorDiscoveryIsRetrying()
		discoverDescriptors()
	}
	
	/// Called when descriptor discovery is retrying
	func descriptorDiscoveryIsRetrying() {
		retryingDiscoveryStep()
	}
	
	//MARK: Subscribing
	
	/**
	Override this to decide if any characteristics should be subscribed to.
	
	Default behavior is to subscribe to any characteristic that supports notify.
	
	- parameter character: The characteristic
	- parameter service:   The service
	- returns: Bool
	*/
	public func shouldSubscribeToCharacteristic(character:CBCharacteristic?, service:CBService?) -> Bool {
		return true
	}
	
	/// Starts the subscribe step
	func startSubscribing() {
		setNotifyCount = 0
		isInSetup = true
		
		if let services = cbPeripheral?.services {
			for service in services {
				if let chars = service.characteristics {
					for char in chars {
						if char.properties.contains(.Notify) {
							if shouldSubscribeToCharacteristic(char,service:service) {
								setNotifyCount = setNotifyCount + 1
							}
						}
					}
				}
			}
			
			if setNotifyCount < 1 {
				onSubscribeComplete()
				return
			}
			
			for service in services {
				if let chars = service.characteristics {
					for char in chars {
						if char.properties.contains(.Notify) {
							if shouldSubscribeToCharacteristic(char,service:service) {
								cbPeripheral?.setNotifyValue(true, forCharacteristic: char)
							}
						}
					}
				}
			}
		}
	}
	
	/// Start timeout for subscribe step
	func startTimerForSubscribeStep() {
		timeout?.invalidate()
		attempts = maxAttempts
		timeout = NSTimer.scheduledTimerWithTimeInterval(attemptTimeoutLength, target: self, selector: #selector(BTLEPlusPeripheral.subscribingTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	/// Timeout for subscribe step
	func subscribingTimeout(timer:NSTimer?) {
		retrySubscribing()
	}
	
	/// Retry subscribe step
	func retrySubscribing() {
		attempts = attempts - 1
		if attempts < 1 {
			subscribeStepFailed()
			return
		}
		retryingSubscribing()
		startSubscribing()
	}
	
	/// retrying for subscribe step
	func retryingSubscribing() {
		retryingSubscribeStep()
	}
	
	/// When a setNotify received an error
	func subscribingReceivedError(error:NSError?) {
		setupOutgoingError = error
		retrySubscribing()
	}
	
	/// Subsribing finished successfully.
	public func onSubscribeComplete() {
		
		////check if additional setup is required.
		if requiresAdditionalSetup() {
			internal_performAdditionalSetup()
			return
		}
		
		if isPeripheralReady() {
			onPeripheralReady()
		}
	}
	
	//MARK: Additional setup
	
	/**
	Whether or not your peripheral requires additional setup after
	subscribing to characteristics.
	
	- returns: Bool
	*/
	public func requiresAdditionalSetup() -> Bool {
		return false
	}
	
	/// internal function that kicks off performAdditionalSetup
	func internal_performAdditionalSetup() {
		attempts = maxAttempts
		performAdditionalSetup()
	}
	
	/**
	Override this to perform your additional setup tasks.
	
	**Make sure to call super.performAdditionalSetup()**
	*/
	public func performAdditionalSetup() {
		attempts = attempts - 1
		timeout?.invalidate()
		timeout = NSTimer.scheduledTimerWithTimeInterval(attemptTimeoutLength, target: self, selector: #selector(BTLEPlusPeripheral.additionalSetupTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	func retryPerformAddionalSetup() {
		attempts = attempts - 1
		if attempts < 1 {
			additionalSetupFailed()
		}
		retryingAdditionalSetup()
		performAdditionalSetup()
	}
	
	func retryingAdditionalSetup() {
		
	}
	
	func additionalSetupTimeout(timer:NSTimer?) {
		retryPerformAddionalSetup()
	}
	
	func additionalSetupFailed() {
		let userinfo = [NSLocalizedDescriptionKey:"Additional setup timed out."];
		let error = NSError(domain: "ble", code: 0, userInfo: userinfo)
		btleCentralManager?.delegate?.btlePeripheralSetupFailed?(btleCentralManager!, peripheral: self, error: error)
	}
	
	//MARK: Utils
	
	/**
	Find a service.
	
	- parameter uuid: The service CBUUID.
	- returns: CBService?
	*/
	public func findService(uuid:CBUUID) -> CBService? {
		if let services = cbPeripheral?.services {
			for service in services {
				if service.UUID == uuid {
					return service
				}
			}
		}
		return nil
	}
	
	/**
	Find a characteristic from a service.
	
	- parameter service: A CBService that may contain a characteristic with uuid.
	- parameter uuid: Characteristic uuid.
	- returns: CBCharacteristic?
	*/
	public func findCharacteristic(service:CBService?, uuid:CBUUID) -> CBCharacteristic? {
		guard let service = service else {
			return nil
		}
		if let chars = service.characteristics {
			for char in chars {
				if char.UUID == uuid {
					return char
				}
			}
		}
		return nil
	}
	
	// MARK: CBPeripheral Delegate
	
	// Peripheral discovered it's services.
	public func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
		/// If we're not in setup step, allow subclasses to do what they want.
		if !isInSetup {
			return
		}
		
		if let error = error {
			discoverServicesReceivedError(error)
			return
		}
		
		discoverIncludedServices()
	}
	
	//Discovered some included services for a service
	public func peripheral(peripheral: CBPeripheral, didDiscoverIncludedServicesForService service: CBService, error: NSError?) {
		
		/// If we're not in setup step, allow subclasses to do what they want.
		if !isInSetup {
			return
		}
		
		if let error = error {
			discoverIncludedServicesReceivedError(error)
			return
		}
		
		discoveringIncludedServices = discoveringIncludedServices - 1
		if discoveringIncludedServices == 0 {
			discoverCharacteristics()
		}
	}
	
	// Discovered some characteristics for a service
	public func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
		
		/// If we're not in setup step, allow subclasses to do what they want.
		if !isInSetup {
			return
		}
		
		if let error = error {
			discoverCharacteristicsReceivedError(error)
			return
		}
		
		discoveringCharacteristics = discoveringCharacteristics - 1
		if discoveringCharacteristics == 0 {
			discoverDescriptors()
		}
	}
	
	//Services were invalidated for a peripheral.
	public func peripheral(peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
		servicesWereInvalidated()
	}
	
	//Discovered descriptors for a characteristic.
	public func peripheral(peripheral: CBPeripheral, didDiscoverDescriptorsForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
		
		/// If we're not in setup step, allow subclasses to do what they want.
		if !isInSetup {
			return
		}
		
		if let error = error {
			discoverDescriptorsReceivedError(error)
			return
		}
		
		discoveringDescriptors = discoveringDescriptors - 1
		if discoveringDescriptors == 0 {
			startSubscribing()
		}
	}
	
	//A characteristics notification state changed.
	public func peripheral(peripheral: CBPeripheral, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
		
		/// If we're not in setup step, allow subclasses to do what they want.
		if !isInSetup {
			return
		}
		
		if let error = error {
			subscribingReceivedError(error)
			return
		}
		
		setNotifyCount = setNotifyCount - 1
		if setNotifyCount == 0 {
			onSubscribeComplete()
		}
	}
	
	//A peripheral invalidated it's services
	public func peripheralDidInvalidateServices(peripheral: CBPeripheral) {
		servicesWereInvalidated()
	}
	
	//Peripheral did update name
	public func peripheralDidUpdateName(peripheral: CBPeripheral) {
		updatedName()
	}
	
	//Peripheral did update RSSI
	public func peripheralDidUpdateRSSI(peripheral: CBPeripheral, error: NSError?) {
		if let error = error {
			updatedRSSIReceivedError(error)
			return
		}
		updatedRSSI()
	}
}
