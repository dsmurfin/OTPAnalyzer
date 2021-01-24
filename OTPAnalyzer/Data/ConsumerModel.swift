//
//  ConsumerModel.swift
//
//  Copyright (c) 2020 Daniel Murfin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import OTPKit

/**
 Consumer Model Delegate
 
 Required methods for objects implementing this delegate.

*/

protocol ConsumerModelDelegate: AnyObject {
    
    /**
     Notifies the delegate that new or changed producers were discovered.
     
     - Parameters:
        - index: The index of this producer in the array of producers, where it has already been added to the table view.

    */
    func changedProducer(atIndex index: Int?)
    
    /**
     Notifies the delegate that new or changed points were discovered.
    */
    func changedPoints()
    
}

/**
 Consumer Model
 
 Data model for a consumer.

*/

class ConsumerModel {
    
    /// The queue used for read/write operations.
    static let queue: DispatchQueue = DispatchQueue(label: "com.danielmurfin.OTPAnalyzer.consumerModelQueue", attributes: .concurrent)
    
    /// The queue on which delegate notifications occur.
    static let delegateQueue: DispatchQueue = DispatchQueue(label: "com.danielmurfin.OTPKit.consumerModelDelegateQueue")

    /// The log for this consumer.
    let log = Log()
    
    /// Whether debug socket messages should be logged.
    private var logDebugSocket = false
    
    /// A unique identifier for this consumer.
    private (set) var identifierCid = UUID()
    
    /// The system numbers which should be observed by the consumer.
    var observedSystemNumbers: [OTPSystemNumber] {
        get { Self.queue.sync { _observedSystemNumbers } }
    }
    
    /// The system numbers which should be observed by the consumer (internal).
    private var _observedSystemNumbers = [OTPSystemNumber]()
    
    /// The system numbers which have been discovered by the consumer.
    var discoveredSystemNumbers: [OTPSystemNumber] {
        get { Self.queue.sync { _discoveredSystemNumbers } }
    }
    
    /// The system numbers which have been discovered by the consumer (internal).
    private var _discoveredSystemNumbers = [OTPSystemNumber]()
    
    /// An optional consumer for this view controller.
    private var consumer: OTPConsumer?
    
    /// The points received by this consumer.
    var points: [OTPPoint] {
        get { Self.queue.sync { _points } }
    }
    
    /// The points received by this consumer (internal).
    private var _points = [OTPPoint]()
    
    /// The producers discovered by this consumer.
    var producers: [OTPProducerStatus] {
        get { Self.queue.sync { _producers } }
    }
    
    /// The producers discovered by this consumer (internal).
    private var _producers: [OTPProducerStatus] = []
    
    /// Whether this consumer has been started.
    var started: Bool {
        get { Self.queue.sync { _started } }
    }
    
    /// Whether this consumer has been started (internal).
    private var _started = false {
        didSet { _started ? controllerDelegate?.startedConsumer() : controllerDelegate?.stoppedConsumer() }
    }

    /// The selected interface name.
    var interfaceName: String? {
        get { Self.queue.sync { _interfaceName } }
        set (newValue) { return Self.queue.sync(flags: .barrier) { _interfaceName = newValue } }
    }
    
    /// The selected interface name (internal).
    private var _interfaceName: String?
    
    /// The consumer controller delegate which wishes to receive delegate calls.
    weak var controllerDelegate: ConsumerControllerDelegate?
    
    /// The consumer model delegate which wishes to receive delegate calls.
    weak var modelDelegate: ConsumerModelDelegate?
    
    /**
     Starts the consumer.
     
     - Parameters:
        - name: A name for this consumer.
        - ipMode: The IP mode for this consumer (IPv4/IPv6/Both).
        - moduleTypes: The types of modules this consumer is interested in receiving.
        - interval: The minimum interval between consumer delegate notifications.
        - logErrors: Whether protocol errors should be logged.
        - logDebug: Whether debug messages should be logged.
        - logSocket: Whether socket messages should be logged.

    */
    func startConsumer(name: String, ipMode: OTPIPMode, moduleTypes: [OTPModule.Type], interval: Int, logErrors: Bool, logDebug: Bool, logSocket: Bool) {
        
        Self.queue.sync(flags: .barrier) {
            
            // only reinitialize when required
            if consumer == nil {
        
                // there must be an interface selected
                guard let interface = self._interfaceName else { log.add(message: "No interface selected", ofType: .unknown); return }
                
                // initialize the consumer
                self.consumer = OTPConsumer(name: name, cid: self.identifierCid, ipMode: ipMode, interface: interface, moduleTypes: moduleTypes, observedSystems: self._observedSystemNumbers, delegateQueue: Self.delegateQueue, delegateInterval: interval)
                
                self.log.add(message: "Initialized consumer \(self.identifierCid)", ofType: .debug)
                
                // if checked, set this controller to be the delegate
                self.logDebugSocket = logSocket
                self.consumer?.setProtocolErrorDelegate(logErrors ? self : nil)
                self.consumer?.setDebugDelegate(logErrors ? self : nil)
                self.consumer?.setConsumerDelegate(self)
                
            }

            do {
                
                // attempt to start the consumer
                try self.consumer?.start()
                
                // the consumer is started
                self._started = true
                
                self.log.add(message: "Consumer started", ofType: .info)
                
            } catch let error as ComponentSocketError {
                self.log.add(message: error.logDescription, ofType: .socket)
            } catch let error {
                self.log.add(message: error.localizedDescription, ofType: .unknown)
            }
            
        }
        
    }
    
    /**
     Stops this consumer.
    */
    func stopConsumer() {
        
        Self.queue.sync(flags: .barrier) {
        
            // the consumer must be started
            guard self._started else { return }
            
            // stop the consumer
            self.consumer?.stop()
            
            // the consumer is stopped
            self._started = false
            
            self.log.add(message: "Consumer stopped", ofType: .info)
            
        }
        
    }
    
    /**
     Resets the consumers.
    */
    func resetConsumer() {
        
        // there must be a consumer to reset
        guard let _ = (Self.queue.sync { self.consumer }) else { return }
        
        self.stopConsumer()
        
        Self.queue.sync(flags: .barrier) {
            
            // create a new identifier
            self.identifierCid = UUID()
            
            // reset the consumer
            self.consumer = nil
            
            // remove all points
            self._points = []
            
            // remove all discovered system numbers
            self._observedSystemNumbers = []
            self._discoveredSystemNumbers = []
            
            // remove all discovered producers
            self._producers = []

            // clear the logs
            log.reset()
            
        }
        
    }
    
    /**
     Resets the logs.
     */
    func resetLogs() {
        Self.queue.sync(flags: .barrier) {
            log.reset()
        }
    }
    
    /**
     Updates the name of the consumer.
     
     - Parameters:
        - name: The name to be assigned to the consumer.
     
    */
    func updateConsumerName(_ name: String) {
        
        Self.queue.sync {
            self.consumer?.update(name: name)
        }
        
    }
    
    /**
     Adds interested module types to this consumer.
     
     - Parameters:
        - moduleTypes: The module types to be added.

    */
    func addModuleTypes(_ moduleTypes: [OTPModule.Type]) {
        
        Self.queue.sync {
            self.consumer?.addModuleTypes(moduleTypes)
        }
        
    }
    
    /**
     Removes module types this consumer is not longer interested in from this consumer.
     
     - Parameters:
        - moduleTypes: The module types to be removed.

    */
    func removeModuleTypes(_ moduleTypes: [OTPModule.Type]) {
        
        Self.queue.sync {
            self.consumer?.removeModuleTypes(moduleTypes)
        }
        
    }
    
    /**
     Updates the observed system numbers of this consumer.
     
     - Parameters:
        - systemNumbers: The system numbers to be observed.

    */
    func observeSystemNumbers(_ systemNumbers: [OTPSystemNumber]) {
        
        Self.queue.sync(flags: .barrier) {

            self._observedSystemNumbers = systemNumbers
        
            self.consumer?.observeSystemNumbers(systemNumbers)

        }
        
    }
    
    /**
     Requests names from any producers on the network.

    */
    func requestNames() {
        consumer?.requestProducerPointNames()
    }
    
    /**
     Changes whether errors should be logged by this consumer model.
     
     - Parameters:
        - log: Whether errors should be logged.
     
    */
    func logErrors(_ log: Bool) {
        Self.queue.sync {
            consumer?.setProtocolErrorDelegate(log ? self : nil)
        }
    }
    
    /**
     Changes whether debug messages should be logged by this producer model.
     
     - Parameters:
        - log: Whether debug messages should be logged.
     
    */
    func logDebug(_ log: Bool) {
        Self.queue.sync {
            consumer?.setDebugDelegate(log ? self : nil)
        }
    }
    
    /**
     Changes whether debug socket messages should be logged by this consumer model.
     
     - Parameters:
        - log: Whether debug messages should be logged.
     
    */
    func logDebugSocket(_ log: Bool) {
        Self.queue.sync(flags: .barrier) {
            logDebugSocket = log
        }
    }
    
}

// MARK: -
// MARK: -

/**
 OTP Consumer Delegate
 
 Required methods for objects implementing this delegate.

*/

extension ConsumerModel: OTPConsumerDelegate {

    /**
     Called to notify the delegate of all points.
     
     - Parameters:
        - points: Merged points from all online producers.

    */
    func replaceAllPoints(_ points: [OTPPoint]) {

        Self.queue.sync(flags: .barrier) {
            
            // replace all points
            self._points = points

            // notify the delegate
            modelDelegate?.changedPoints()
            
        }
        
    }
    
    /**
     Called to notify the delegate that a consumer has changes for points.
     
     - Parameters:
        - points: The points with changes.

    */
    func changes(forPoints points: [OTPPoint]) {

        Self.queue.sync(flags: .barrier) {
            
            // replace any existing points with the same address with those received
            self._points = Array(Set(points).union(self._points)).sorted()

            // notify the delegate
            modelDelegate?.changedPoints()
            
        }
        
    }
    
    /**
     Called to notify the delegate that a producer's status has changed.
     
     - Parameters:
        - producer: The producer which has changed.

    */
    func producerStatusChanged(_ producer: OTPProducerStatus) {

        Self.queue.sync(flags: .barrier) {

            // check if this producer already exists
            if let index = self._producers.firstIndex(where: { $0.cid == producer.cid }) {
                
                // replace it
                self._producers[index] = producer
                
                // notify the delegate
                modelDelegate?.changedProducer(atIndex: index)
                
            } else {
                
                self._producers.append(producer)
                
                // notify the delegate
                modelDelegate?.changedProducer(atIndex: nil)
                
            }
            
        }
        
    }
    
    /**
     Called to notify the delegate of the system numbers of producers on the network being advertised to this consumer.
     
     - Parameters:
        - systemNumbers: The system numbers this consumer has discovered.
     
    */
    func discoveredSystemNumbers(_ systemNumbers: [OTPSystemNumber]) {

        // update the discovered system numbers
        Self.queue.sync(flags: .barrier) {
            self._discoveredSystemNumbers = systemNumbers
        }

    }
    
}

// MARK: -
// MARK: -

/**
 OTP Component Protocol Error Delegate
 
 Required methods for objects implementing this delegate.

*/

extension ConsumerModel: OTPComponentProtocolErrorDelegate {
    
    /**
     Called whenever layer parsing errors occur.
     
     - Parameters:
        - errorDescription: A human-readable description of the error.
     
    */
    func layerError(_ errorDescription: String) {
        log.add(message: errorDescription, ofType: .protocolLayer)
    }
    
    /**
     Called whenever sequence errors occur.
     
     - Parameters:
        - errorDescription: A human-readable description of the error.
     
    */
    func sequenceError(_ errorDescription: String) {
        log.add(message: errorDescription, ofType: .protocolSequence)
    }
    
    /**
     Called whenever unknown errors occur
     
     - Parameters:
        - errorDescription: A human-readable description of the error.
     
    */
    func unknownError(_ errorDescription: String) {
        log.add(message: errorDescription, ofType: .protocolUnknown)
    }
    
}

// MARK: -
// MARK: -

/**
 OTP Component Debug Delegate
 
 Required methods for objects implementing this delegate.

*/

extension ConsumerModel: OTPComponentDebugDelegate {
    
    /**
     Called whenever a debug message is logged.
     
     - Parameters:
        - logMessage: A human-readable log message.
     
    */
    func debugLog(_ logMessage: String) {
        log.add(message: logMessage, ofType: .debug)
    }
    
    /**
     Called whenever a debug socket message is logged.
     
     - Parameters:
        - logMessage: A human-readable log message.
     
    */
    func debugSocketLog(_ logMessage: String) {
        
        let logDebugSocket = Self.queue.sync { self.logDebugSocket }
        
        // only log if set
        guard logDebugSocket else { return }
        
        log.add(message: logMessage, ofType: .socket)
        
    }
    
}
