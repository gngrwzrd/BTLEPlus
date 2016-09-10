
import CoreBluetooth

/**
The BLEPeripheral object is a generic peripheral that allows you to customize
the connection and setup process before it's considered ready to use.

## Peripheral Setup

Each peripheral goes through this setup process before it's considered ready
to use. And must go through the same setup process if it's disconnected and
then reconnected.

Each step in the setup process has retries and timeouts you can customize.
If something fails or times-out it will try the same step up to a specified
max attemps.

#### Connect Step

This is the first step in the process and is handled by a BLECentralManager.
After your central discovers peripherals, you connect to the desired peripheral with
_myBLECentralManager.connect(peripheral:)_.

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

Peripheral objects aren't created and used directly, instead you create
a prototype object, and register it with a BTLECentralManager.

When a BTLECentralManager discovers peripherals, it asks each registered BTLEPeripheral
prototype if it knows how to respond to the advertised services. You can override
respondsToAdvertisementData(), which tells the central manager if it should
instantiate your peripheral.

## Responding to Advertisement Data

````
class MyPeripheral : BLEPeripheral {
	//override and decide if your peripheral understands the advertised data.
	override public func respondsToAdvertisementData(data:BLEAdvertisementData) -> Bool {
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
the advertisement data for a peripheral is collected using a BLEAdvertisementData
object. Your peripheral prototype will be asked each time with the collected data if it
responds to the advertisement data. This ensures you eventually get all of the advertisement
data to properly decide if your prototype understands the advertised services.

*/
@objc public class BLEPeripheral : NSObject, CBPeripheralDelegate {
	
	//MARK: CBPeripheral
	
	/// The CBPeripheral this class monitors and manages.
	public var cbPeripheral:CBPeripheral?
	
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
	
	/// Whether or not this peripheral should be removed from it's BLECentralManager.
	/// This is called when a peripheral disconnects.
	///
	/// If false, the peripheral will remain in a disconnected state
	/// within it's BLECentralManager.
	///
	/// If true it's removed from it's BLECentralManager and you'd have
	/// to scan for the peripheral again.
	///
	/// By default this is true.
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
	
	/// The maximum tries to connect to the peripheral.
	public var connectionMaxAttempts = 3
	
	/// The timeout length before retrying to connect to the peripheral.
	public var connectionTimeoutLength:NSTimeInterval = 5
	
	/// The maximum tries to discover services, included services, characteristics and descriptors.
	public var discoveryStepMaxAttempts = 3
	
	/// The discovery step timeout length before retrying the discover step.
	public var discoveryStepTimeoutLength:NSTimeInterval = 5
	
	/// The maximum tries to subscribe to a characteristic.
	public var subscribeStepMaxAttempts = 3
	
	/// The subscribe step timeout length before retrying the subscribe step.
	public var subscribeStepTimeoutLength:NSTimeInterval = 5
	
	/// The maximum attempts to call performAdditionalSetup().
	public var additionalSetupMaxAttempts = 3
	
	/// The timeout for custom additional setup.
	public var additionalSetupTimeout:NSTimeInterval = 5
	
	/// The BLECentralManager that currently is managing this peripheral.
	weak var bleCentralManager:BLECentralManager?
	
	/// The CBCentralManager for this peripheral.
	weak var btCentralManager:CBCentralManager?
	
	/// Utility variable for all retry logic that keeps track of how many more attempts are allowed.
	var attempts = 0
	
	/// Utility variable for any timeout required which would trigger another attempt.
	var timeout:NSTimer?
	
	/// Whether or not the peripheral is going through it's setup step before it's considered ready.
	/// This flag is needed in order to allow subclasses to override peripheral delegate methods properly.
	var isInSetup = false
	
	/// Whether or not the discover step of peripheral setup is completed.
	var discoveryRequirementsCompleted:Bool = false
	
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
	
	/// Whether the last disconnect was the result of a call to disconnect()
	/// by the user, or an internal disconnect because of an outside condition.
	var disconnectWasInternal:Bool = false
	
	//MARK: Advertisement Data
	
	var _advertisementData:BLEAdvertisementData?
	/// Initial advertisement data when peripheral was discovered. Note that this
	/// data can also come from user defaults when peripherals are retrieved from
	/// core bluetooth.
	public var advertisementData:BLEAdvertisementData? {
		get {
			return _advertisementData
		} set(newAdvertisementData) {
			_advertisementData = newAdvertisementData
		}
	}
	
	/// This is called when a new BLEPeripheral instance is created from a prototype copy.
	func wasCopiedFromPeripheralPrototype(prototype:BLEPeripheral) {
		attempts = prototype.connectionMaxAttempts
	}
	
	/// You must override this and implement logic that decides if your peripheral
	/// responds to the advertisement data.
	public func respondsToAdvertisementData(advertisementData:BLEAdvertisementData) -> Bool {
		return false
	}
	
	/// Called when a peripheral receives more advertisement data. This can happen
	/// when peripheral discovery is running. Core bluetooth will send multiple
	/// peripheral discovered for the same peripheral, but with more data.
	func receivedMoreAdvertisementData(newData:BLEAdvertisementData) {
		advertisementData?.append(newData)
		if peripheralReady {
			bleCentralManager?.saveKnownPeripheral(self, advertisementData: advertisementData)
		}
	}
	
	//MARK: Restoring from Core Bluetooth
	
	/// When a peripheral was retrieved from core bluetooth.
	public func wasRetrieved() {
		if cbPeripheral?.state == CBPeripheralState.Disconnected {
			connect()
		}
		if cbPeripheral?.state == CBPeripheralState.Connected {
			discoverServices()
		}
	}
	
	//MARK: Connectivity
	
	/// You can override this to be notified of when a peripheral was discovered. It's
	/// also called when a peripheral is `retrieved` from core bluetooth and considered discovered.
	public func wasDiscovered() {
		bleCentralManager?.delegate?.bleCentralManagerDidDiscoverPeripheral?(bleCentralManager!, peripheral: self)
	}
	
	/// This starts the connect process with core bluetooth.
	func connect() {
		if let peripheral = cbPeripheral {
			if peripheral.state == CBPeripheralState.Connecting || peripheral.state == CBPeripheralState.Connected {
				return
			}
		}
		attempts = connectionMaxAttempts
		lastDisconnectError = nil
		isInSetup = true
		retryConnect()
	}
	
	/// When the peripheral is connected. The peripheral has only been connected
	/// and not ready for use yet.
	func connected() {
		cbPeripheral?.delegate = self
		bleCentralManager?.delegate?.blePeripheralConnected?(bleCentralManager!, peripheral: self)
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
			discoveryRequirementsCompleted = false
			peripheralReady = false
			startConnectTimeout()
			btCentralManager?.connectPeripheral(peripheral, options: nil)
		}
	}
	
	/// Starts the connection timeout
	func startConnectTimeout() {
		timeout?.invalidate()
		timeout = NSTimer.scheduledTimerWithTimeInterval(connectionTimeoutLength, target: self, selector: #selector(BLEPeripheral.connectTimeout(_:)), userInfo: nil, repeats: false)
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
	
	/// This is called when max connection attempts have been
	/// made and it still won't connect.
	func connectFailed() {
		bleCentralManager?.delegate?.blePeripheralFailedToConnect?(bleCentralManager!, peripheral: self, error: setupOutgoingError)
		internal_disconnect()
		if canBeRemovedFromManager {
			bleCentralManager?.removePeripheral(self)
		}
	}
	
	/// Disconnect this peripheral. Once disconnected the peripheral will be removed
	/// from the BLECentralManager. You can optionally override `canBeRemovedFromManager()`
	/// to allow the peripheral to continue living in a disconnected state.
	func disconnect() {
		disconnectWasInternal = false
		if cbPeripheral?.state == CBPeripheralState.Disconnected {
			return
		}
		if let peripheral = cbPeripheral {
			btCentralManager?.cancelPeripheralConnection(peripheral)
		}
	}
	
	/// A private form of disconnect soley for setting the disconnectWasInternal
	/// flag.
	private func internal_disconnect() {
		disconnectWasInternal = true
		if cbPeripheral?.state == CBPeripheralState.Disconnected {
			return
		}
		if let peripheral = cbPeripheral {
			btCentralManager?.cancelPeripheralConnection(peripheral)
		}
	}
	
	/// Called when the peripheral is disconnected.
	public func onDisconnected() {
		bleCentralManager?.delegate?.blePeripheralDisconnected?(bleCentralManager!, peripheral: self)
		
		isInSetup = false
		cbPeripheral?.delegate = nil
		
		if shouldReconnectOnDisconnect {
			connect()
		}
		
		if !shouldReconnectOnDisconnect && canBeRemovedFromManager {
			bleCentralManager?.removePeripheral(self)
		}
	}
	
	/// When the BLECentralManager receives a disconnect for this peripheral.
	func btCentralManagerReceivedDisconnect() {
		onDisconnected()
	}
	
	/// When the BLECentralManager receives a disconnect for this peripheral and receives and error.
	func btCentralManagerReceivedDisconnectError(error:NSError?) {
		lastDisconnectError = error
		setupOutgoingError = error
		onDisconnected()
	}
	
	//MARK: Peripheral Ready
	
	/// Whether or not this peripheral is ready. BLEPeripheral uses this as a flag
	/// in numerous places to skip parts of the discovery / subscribe
	/// step if subclasses set it to true.
	public var peripheralReady = false
	
	/// Returns whether the peripheral is considered ready. You can override this
	/// to provide your own logic that decides of the peripheral is ready.
	public func isPeripheralReady() -> Bool {
		return peripheralReady
	}
	
	/// When the peripheral is ready this is called.
	public func peripheralIsReady() {
		timeout?.invalidate()
		timeout = nil
		isInSetup = false
		bleCentralManager?.saveKnownPeripheral(self,advertisementData: advertisementData)
		bleCentralManager?.delegate?.blePeripheralIsReady?(bleCentralManager!, peripheral: self)
	}
	
	/// Called when the discovery step is being retried.
	func retryingDiscoveryStep() {
		
	}
	
	/// Called when the subscribe step is being retried.
	func retryingSubscribeStep() {
		
	}
	
	/// Called when the discover step failed after max discover attempts has passed.
	func discoveryStepFailed() {
		internal_disconnect()
		bleCentralManager?.delegate?.blePeripheralSetupFailed?(bleCentralManager!, peripheral: self, error: setupOutgoingError)
	}
	
	/// Called when descriptor discovery completed.
	func discoveryStepCompleted() {
		startSubscribing()
	}
	
	/// Called when the subscribe step failed after max subscribe attempts has passed.
	func subscribeStepFailed() {
		internal_disconnect()
		bleCentralManager?.delegate?.blePeripheralSetupFailed?(bleCentralManager!, peripheral: self, error: setupOutgoingError)
	}
	
	//MARK: Service Discovery
	
	/**
	Returns whether or not a specific service CBUUID should be discovered as part of the
	discovery step. The passed uuid is taken directly from a peripherals advertisement data.
	
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
			discoveryStepCompleted()
			return
		}
		
		startTimeoutForDiscoverServices()
		cbPeripheral?.discoverServices(servicesToDiscover)
	}
	
	/// Called after services have been discovered.
	func discoveredServices() {
		discoverIncludedServices()
	}
	
	/// Starts the timeout for service discovery.
	func startTimeoutForDiscoverServices() {
		timeout?.invalidate()
		attempts = discoveryStepMaxAttempts
		timeout = NSTimer.scheduledTimerWithTimeInterval(discoveryStepTimeoutLength, target: self, selector: #selector(BLEPeripheral.discoverServicesTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	/// service discovery received an error
	func discoverServicesReceivedError(error:NSError?) {
		attempts = attempts - 1
		if attempts < 1 {
			setupOutgoingError = error
			discoverServicesFailed()
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
	
	/// service discovery failed.
	func discoverServicesFailed() {
		discoveryStepFailed()
	}
	
	/// When services are invalidated, your peripheral goes through the setup process
	/// again to discover services, included services, characteristics and descriptors.
	public func servicesWereInvalidated() {
		discoveryRequirementsCompleted = false
		peripheralReady = false
		discoverServices()
	}
	
	//MARK: Included Service Discovery
	
	public func shouldDiscoverIncludedServices() -> Bool {
		return false
	}
	
	/**
	Controls whether or not included services for a service should be discovered. And
	which of the services should be discovered.
	
	- parameter service: The service who's included services should be discovered.
	- returns: Returning [CBUUID,] means specific services, [] means all included services, nil means don't discover any included services
	*/
	public func discoverIncludedServicesForService(service:CBService?) -> [CBUUID]? {
		return nil
	}
	
	/// Starts the discovery of included services.
	func discoverIncludedServices() {
		isInSetup = true
		
		if !shouldDiscoverIncludedServices() {
			if discoveryRequirementsCompleted {
				discoveryStepCompleted()
			} else {
				discoverCharacteristics()
			}
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
		attempts = discoveryStepMaxAttempts
		timeout = NSTimer.scheduledTimerWithTimeInterval(discoveryStepTimeoutLength, target: self, selector: #selector(BLEPeripheral.discoverIncludedServicesTimeout(_:)), userInfo: nil, repeats: false)
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
			discoverIncludedServicesFailed()
			return
		}
		discoverIncludedServicesIsRetrying()
		discoverIncludedServices()
	}
	
	/// Called when discovering included services failed.
	func discoverIncludedServicesFailed() {
		discoveryStepFailed()
	}
	
	/// Called when discovering included services is retrying.
	func discoverIncludedServicesIsRetrying() {
		retryingDiscoveryStep()
	}
	
	/// Called when discovered included services completed.
	func discoveredIncludedServices() {
		discoverCharacteristics()
	}
	
	//MARK: Characteristics Discovery
	
	/**
	Whether or not to discover characteristics. Default is true.
	
	Default return value is true.
	
	- returns: Bool
	*/
	public func shouldDiscoverCharacteristics() -> Bool {
		return true
	}
	
	/**
	Whether or not all characteristics for a specific service should be discovered.
	If shouldDiscoverCharacteristics() returns false this won't be called.
	
	Default behavior is to discover all characteristics for a service.
	
	- parameter service: The service who's characteristics will be discovered.
	- returns: [CBUUID,] means specific characteristic, [] means all characteristics, 
	nil means don't discover any characteristics for this service.
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
			if discoveryRequirementsCompleted {
				discoveryStepCompleted()
			}
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
			discoveryStepCompleted()
		}
	}
	
	/// Starts the timeout for characteristic discovery.
	func startTimeoutForDiscoverCharacteristics() {
		attempts = discoveryStepMaxAttempts
		timeout = NSTimer.scheduledTimerWithTimeInterval(discoveryStepTimeoutLength, target: self, selector: #selector(BLEPeripheral.discoverCharacteristicsTimeout(_:)), userInfo: nil, repeats: false)
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
			discoverCharacteristicsFailed()
			return
		}
		discoverCharacteristicsIsRetrying()
		discoverCharacteristics()
	}
	
	/// Called when characteristics discovery failed.
	func discoverCharacteristicsFailed() {
		discoveryStepFailed()
	}
	
	/// Successfully discovered characteristics.
	public func discoveredCharacteristics() {
		discoverDescriptors()
	}
	
	//MARK: Descriptor Discovery
	
	/**
	Whether or not descriptors should be discovered.
	
	Default return value is false.
	
	- returns: Bool
	*/
	public func shouldDiscoverDescriptors() -> Bool {
		return false
	}
	
	/**
	Override this to customize which descriptors for a characteristics and service are
	going to be discovered. If shouldDiscoverDescriptors() returns false, this
	won't be called.
	
	Default behavior is to discover all descriptors.
	
	- parameter characteristic: The characteristic.
	- parameter service:        The service
	- returns: Bool
	*/
	public func shouldDiscoverDescriptorsForCharacteristic(characteristic:CBCharacteristic, service:CBService?) -> Bool {
		return true
	}
	
	/// Starts the descriptor discovery.
	func discoverDescriptors() {
		isInSetup = true
		
		if !shouldDiscoverDescriptors() {
			if discoveryRequirementsCompleted {
				discoveryStepCompleted()
			} else {
				startSubscribing()
			}
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
				if discoveryRequirementsCompleted {
					discoveryStepCompleted()
				}
			}
		}
	}
	
	/// Called when descriptors were discovered.
	public func discoveredDescriptors() {
		discoveryStepCompleted()
	}
	
	/// Starts the timeout for descriptor discovery
	func startTimeoutForDiscoverDescriptors() {
		attempts = discoveryStepMaxAttempts
		timeout = NSTimer.scheduledTimerWithTimeInterval(discoveryStepTimeoutLength, target: self, selector: #selector(BLEPeripheral.discoverDescriptorsTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	/// Timeout of descriptor discovery
	func discoverDescriptorsTimeout(timer:NSTimer) {
		discoverDescriptorsReceivedError(nil)
	}
	
	/// Called when descriptor discovery failed
	func discoverDescriptorsFailed() {
		discoveryStepFailed()
	}
	
	/// Called when discovering a descriptor received an error
	func discoverDescriptorsReceivedError(error:NSError?) {
		attempts = attempts - 1
		if attempts < 1 {
			setupOutgoingError = error
			discoverDescriptorsFailed()
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
	
	Default return value is true for any characteristic that implements the notify property.
	
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
				subscribingFinished()
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
		attempts = subscribeStepMaxAttempts
		timeout = NSTimer.scheduledTimerWithTimeInterval(subscribeStepTimeoutLength, target: self, selector: #selector(BLEPeripheral.subscribingTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	/// Timeout for subscribe step
	func subscribingTimeout(timer:NSTimer?) {
		retrySubscribing()
	}
	
	/// Retry subscribe step
	func retrySubscribing() {
		attempts = attempts - 1
		if attempts < 1 {
			subscribingFailed()
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
	
	/// When the subscribe step failed.
	func subscribingFailed() {
		subscribeStepFailed()
	}
	
	/// Subsribing finished successfully.
	public func subscribingFinished() {
		
		////check if additional setup is required.
		if requiresAdditionalSetup() {
			internal_performAdditionalSetup()
			return
		}
		
		if isPeripheralReady() {
			peripheralIsReady()
		}
	}
	
	//MARK: Additional setup
	
	/// You can override this if you require
	/// additional work as part of the peripheral setup process.
	public func requiresAdditionalSetup() -> Bool {
		return false
	}
	
	/// internal function that kicks off performAdditionalSetup
	func internal_performAdditionalSetup() {
		attempts = additionalSetupMaxAttempts
		performAdditionalSetup()
	}
	
	/// You must override this to perform your
	/// additional setup tasks. Make sure to call super.performAdditionalSetup()
	public func performAdditionalSetup() {
		attempts = attempts - 1
		timeout?.invalidate()
		timeout = NSTimer.scheduledTimerWithTimeInterval(additionalSetupTimeout, target: self, selector: #selector(BLEPeripheral.additionalSetupTimeout(_:)), userInfo: nil, repeats: false)
	}
	
	public func retryPerformAddionalSetup() {
		attempts = attempts - 1
		if attempts < 1 {
			additionalSetupFailed()
		}
		retryingAdditionalSetup()
		performAdditionalSetup()
	}
	
	public func retryingAdditionalSetup() {
		
	}
	
	func additionalSetupTimeout(timer:NSTimer?) {
		retryPerformAddionalSetup()
	}
	
	public func additionalSetupFailed() {
		let userinfo = [NSLocalizedDescriptionKey:"Additional setup timed out."];
		let error = NSError(domain: "ble", code: 0, userInfo: userinfo)
		bleCentralManager?.delegate?.blePeripheralSetupFailed?(bleCentralManager!, peripheral: self, error: error)
	}
	
	//MARK: Utils
	
	/**
	Find a service.
	
	- parameter uuid: The service uuid.
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
	- parameter service: The service.
	- parameter uuid:    Characteristic uuid.
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
		
		discoveredServices()
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
			discoveredIncludedServices()
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
			discoveredCharacteristics()
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
			discoveredDescriptors()
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
			subscribingFinished()
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
