//
//  LauncherController.swift
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

import Cocoa
import NetUtils

/**
 Launcher Controller
 
 Initial view for creating Producers and Consumers.

*/

class LauncherController: NSViewController {
    
    /// Displays a list of discovered network interfaces.
    @IBOutlet var networkInterfacesTableView: NSTableView!
    
    /// Displays a count of producers.
    @IBOutlet var producerCount: NSTextField!
    
    /// Displays a count of producers which are started.
    @IBOutlet var producerStartedCount: NSTextField!
    
    /// Displays a count of consumers.
    @IBOutlet var consumerCount: NSTextField!
    
    /// Displays a count of consumers which are started.
    @IBOutlet var consumerStartedCount: NSTextField!
    
    /// An array of producer controllers.
    private var producerControllers = [ProducerController]()
    
    /// An array of consumer controllers.
    private var consumerControllers = [ConsumerController]()
    
    /// The count of started producers.
    private var startedProducers = 0
    
    /// The count of started consumers.
    private var startedConsumers = 0
    
    /// An array of network interfaces.
    private var interfaces = [Interface]()
    
    /// Used to prevent AppNap.
    private var activity: NSObjectProtocol?
    
    /// Flag used for displaying the pre-release dialog.
    var firstLaunch = true

    /// The segue identifiers for this controller.
    private enum SegueIdentifiers: String {
        case addProducer = "addProducer"
        case addConsumer = "addConsumer"
    }

    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // get an updated list of network interfaces
        refreshInterfaces(self)
        
        // refresh all stats
        refreshProducerStats()
        refreshConsumerStats()

    }
    
    override func viewDidAppear() {
        
        super.viewDidAppear()
        
        guard firstLaunch else { return }
        
        firstLaunch = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
        
            // create and show an alert while in public review
            let alert = NSAlert()
            alert.messageText  = "ESTA BSR E1.59 - 20XX Object Transform Protocol (OTP)\n\nBased on Public Review 3 + Comment Review. This application is intended solely for testing and evaluation."
            alert.informativeText  = "This standard describes a mechanism to transfer object transform information such as position, rotation and velocity over an IP network. It covers data format, data protocol, data addressing, and network management. It does not require real-world location or any association between multiple objects represented in the same message.\n\nData transmitted is intended to coordinate visual and audio elements of a production and should not be used for safety critical applications."
            alert.runModal()
            
        }
        
    }
    
    /**
     Refreshes the display of producer statistics.
    */
    private func refreshProducerStats() {
        
        // refresh all count string values
        producerCount.stringValue = "\(producerControllers.count)"
        producerStartedCount.stringValue = "\(startedProducers)"
        
    }
    
    /**
     Refreshes the display of consumer statistics.
    */
    private func refreshConsumerStats() {
        
        // refresh all count string values
        consumerCount.stringValue = "\(consumerControllers.count)"
        consumerStartedCount.stringValue = "\(startedConsumers)"

    }
    
    /**
     Called when a new view controller is presented via a segue.
    */
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        
        // there must be a valid segue identifier
        guard let identifier = segue.identifier, let segueIdentifier = SegueIdentifiers(rawValue: identifier) else { return }

        switch segueIdentifier {
        case .addProducer:

            // get the destination controller
            guard let controller = segue.destinationController as? NSWindowController, let producerController = controller.contentViewController as? ProducerController else { return }

            // register to receive producer controller notifications
            producerController.viewModel.controllerDelegate = self
            
            producerController.discovered(interfaces: self.interfaces)

            self.producerControllers.append(producerController)
            
            // refresh all stats
            refreshProducerStats()
            
        case .addConsumer:
            
            // get the destination controller
            guard let controller = segue.destinationController as? NSWindowController, let consumerController = controller.contentViewController as? ConsumerController else { return }

            // register to receive consumer controller notifications
            consumerController.viewModel.controllerDelegate = self
            
            consumerController.discovered(interfaces: self.interfaces)

            self.consumerControllers.append(consumerController)
            
            // refresh all stats
            refreshConsumerStats()
            
        }
        
    }
    
    /**
     Stops all producers.
    */
    @IBAction func stopAllProducers(_ sender: AnyObject) {

        // stop and close all producers
        producerControllers.forEach { $0.stop(close: false) }

        // refresh all stats
        refreshProducerStats()
        
    }
    
    /**
     Stops all consumers.
    */
    @IBAction func stopAllConsumers(_ sender: AnyObject) {

        // stop and close all consumers
        consumerControllers.forEach { $0.stop(close: false) }

        // refresh all stats
        refreshConsumerStats()
        
    }
    
    /**
     Closes all producers.
    */
    @IBAction func closeAllProducers(_ sender: AnyObject) {
        
        let controllers = self.producerControllers
        
        // clear all controllers
        self.producerControllers = []
        
        // stop and close all producers
        controllers.forEach { $0.stop(close: true) }
        
        // refresh all stats
        refreshProducerStats()
        
    }
    
    /**
     Closes all consumers.
    */
    @IBAction func closeAllConsumers(_ sender: AnyObject) {
        
        let controllers = self.consumerControllers
        
        // clear all controllers
        self.consumerControllers = []
        
        // stop and close all consumer
        controllers.forEach { $0.stop(close: true) }
        
        // refresh all stats
        refreshConsumerStats()
        
    }
    
    /**
     Refreshes all network interfaces and update the display.
    */
    @IBAction func refreshInterfaces(_ sender: AnyObject) {
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            
            // self must exist still
            guard let self = self else { return }
            
            // get the interfaces we care about
            let interfaces = Interface.allInterfaces().filter { $0.isUp && $0.isRunning && ($0.name.prefix(2) == "en" || $0.name.prefix(2) == "lo") }

            DispatchQueue.main.async { [weak self] in

                self?.interfaces = interfaces
                
                self?.networkInterfacesTableView.reloadData()
                
                // provide the new interfaces to the discovered controllers
                self?.producerControllers.forEach { $0.discovered(interfaces: interfaces) }
                self?.consumerControllers.forEach { $0.discovered(interfaces: interfaces) }

            }
            
        }
        
    }
    
    /**
     Enables or disables AppNap, to prevent the application from being backgrounded.
     
     - Parameters:
        - enable: Whether AppNap should be enabled.
     
    */
    private func appNap(enable: Bool) {
        
        // should AppNap be enabled?
        if enable {
            
            // allow AppNap
            if let activity = activity {
                ProcessInfo().endActivity(activity)
            }
            
        } else {
            
            // prevent AppNap
            activity = ProcessInfo().beginActivity(options: ProcessInfo.ActivityOptions.userInitiated, reason: "Performing Critical Network Operations")
            
        }
        
    }
    
}

// MARK: -
// MARK: -

/**
 Launcher Controller Extension
 
 Extensions to `LauncherController` to handle table view data source and delegate notifications.

*/

extension LauncherController: NSTableViewDataSource, NSTableViewDelegate {
    
    /**
     The column identifiers used for this table view.
    */
    private enum ColumnIdentifiers: String {
        case name = "name"
        case version = "version"
        case multicast = "multicast"
        case address = "address"
        case mask = "mask"
        case broadcast = "broadcast"
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        self.interfaces.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        // there must be a column identifier
        guard let identifier = tableColumn?.identifier, let column = ColumnIdentifiers(rawValue: identifier.rawValue) else { return nil }
        
        // get the interface
        let interface = self.interfaces[row]
        
        switch column {
        case .multicast:
            
            let checkCellView = tableView.makeView(withIdentifier: identifier, owner: self) as! CheckCellView
            
            switch column {
            case .multicast:
                checkCellView.check.checked = interface.supportsMulticast
            default:
                break
            }
            
            // the check should not be enabled
            checkCellView.check.isEnabled = false

            return checkCellView
            
        case .name, .version, .address, .mask, .broadcast:
            
            // create a text cell view
            let textCellView: NSTableCellView = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as! NSTableCellView

            switch column {
            case .name:
                textCellView.textField?.stringValue = interface.name
            case .version:
                textCellView.textField?.stringValue = interface.family.toString()
            case .address:
                textCellView.textField?.stringValue = interface.address ?? ""
            case .mask:
                textCellView.textField?.stringValue = interface.netmask ?? ""
            case .broadcast:
                textCellView.textField?.stringValue = interface.broadcastAddress ?? ""
            default:
                break
            }
            
            // the text field should not be editable
            textCellView.textField?.isEditable = false

            return textCellView
            
        }
        
    }
    
}

// MARK: -
// MARK: -

/**
 Producer Controller Delegate
 
 Required methods for objects implementing this delegate.

*/

extension LauncherController: ProducerControllerDelegate {
    
    /**
     Called whenever a producer controller is about to close.
     
     - Parameters:
        - viewController: The view controller being closed.
     
    */
    func closingProducerController(_ viewController: ProducerController) {

        // this view controller must be in the array
        guard let index = producerControllers.firstIndex(where: { $0 == viewController }) else { return }

        producerControllers.remove(at: index)
        
        // refresh all stats
        refreshProducerStats()
        
    }
    
    /**
     Called whenever a producer controller producer starts.
    */
    func startedProducer() {
        
        startedProducers += 1
        
        // refresh all stats
        refreshProducerStats()
        
        // enable AppNap when there are started consumers or producers
        appNap(enable: startedProducers + startedConsumers == 0)
        
    }
    
    /**
     Called whenever a producer controller producer stops.
    */
    func stoppedProducer() {
        
        startedProducers -= 1
        
        // refresh all stats
        refreshProducerStats()
        
        // enable AppNap when there are started consumers or producers
        appNap(enable: startedProducers + startedConsumers == 0)
        
    }
    
}

/**
 Consumer Controller Delegate
 
 Required methods for objects implementing this delegate.

*/

extension LauncherController: ConsumerControllerDelegate {
    
    /**
     Called whenever a consumer controller is about to close.
     
     - Parameters:
        - viewController: The view controller being closed.
     
    */
    func closingConsumerController(_ viewController: ConsumerController) {

        // this view controller must be in the array
        guard let index = consumerControllers.firstIndex(where: { $0 == viewController }) else { return }

        consumerControllers.remove(at: index)
        
        // refresh all stats
        refreshConsumerStats()
        
    }
    
    /**
     Called whenever a consumer controller consumer starts.
    */
    func startedConsumer() {
        
        startedConsumers += 1
        
        // refresh all stats
        refreshConsumerStats()
        
        // enable AppNap when there are started consumers or producers
        appNap(enable: startedProducers + startedConsumers == 0)

    }
    
    /**
     Called whenever a consumer controller consumer stops.
    */
    func stoppedConsumer() {
        
        startedConsumers -= 1
        
        // refresh all stats
        refreshConsumerStats()
        
        // enable AppNap when there are started consumers or producers
        appNap(enable: startedProducers + startedConsumers == 0)
        
    }
    
}
