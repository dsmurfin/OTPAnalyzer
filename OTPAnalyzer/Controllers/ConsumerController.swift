//
//  ConsumerController.swift
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
import OTPKit
import NetUtils

/**
 Consumer Controller Delegate
 
 Required methods for objects implementing this delegate.

*/

protocol ConsumerControllerDelegate: AnyObject {
    
    /**
     Notifies the delegate that this view controller is about to close.
     
     - Parameters:
        - viewController: The view controller being closed.
     
    */
    func closingConsumerController(_ viewController: ConsumerController)
    
    /**
     Notifies the delegate that this consumer was started.
    */
    func startedConsumer()
    
    /**
     Notifies the delegate that this consumer was stopped.
    */
    func stoppedConsumer()
    
}

// MARK: -
// MARK: -

/**
 Consumer Controller
 
 Creates and displays a new Consumer.

*/

class ConsumerController: NSViewController {
    
    /// Displays the producers discovered by this consumer.
    @IBOutlet var producersTableView: NSTableView!
    
    /// Displays the points received by this consumer.
    @IBOutlet var pointsCollectionView: NSCollectionView!
    
    /// Displays logs from this consumer.
    @IBOutlet var logging: NSTextView!

    /// Used for the human-readable name of this consumer.
    @IBOutlet var name: NSTextField!
    
    /// Used for selection of the Internet Protocol mode of this consumer.
    @IBOutlet var ipMode: NSPopUpButton!
    
    /// Used for selection of the interface this consumer should send/receive on.
    @IBOutlet var interface: NSPopUpButton!
    
    /// Used for selection of the system numbers this consumer should observe.
    @IBOutlet var systems: NSButton!
    
    /// Used for starting and stopping this consumer.
    @IBOutlet var startStopButton: NSButton!
    
    /// Used for resetting the consumer.
    @IBOutlet var reset: NSButton!
    
    /// Used for the selection of error logging for this consumer.
    @IBOutlet var logErrors: NSButton!
    
    /// Used for the selection of debug logging for this consumer.
    @IBOutlet var logDebug: NSButton!
    
    /// Used for the selection of socket logging for this producer.
    @IBOutlet var logDebugSocket: NSButton!
    
    /// Used for the selection of observed modules for this consumer.
    @IBOutlet var modulePos, modulePosVelAccel, moduleRot, moduleRotVelAccel, moduleScale, moduleReferenceFrame: NSButton!
    
    /// Used for requested the names of points.
    @IBOutlet var requestNames: NSButton!

    /// The consumer view model for this controller.
    let viewModel = ConsumerModel()
    
    /// The minimum interval between delegate notifications (ms).
    private static let delegateInterval: Int = 200
    
    /// An array of network interfaces.
    private var interfaces = [Interface]()
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        viewModel.modelDelegate = self
        
        // prepare any text fields
        prepareTextFields()
        
        // prepare any popups
        preparePopups()
        
        // prepare the systems button
        prepareSystemsButton()
        
        // disable buttons
        reset.isEnabled = false
        requestNames.isEnabled = false
        
        // configure the collection view
        configureCollectionView()
        
        // this controller should receive log notifications
        viewModel.log.delegate = self
        viewModel.log.addVersion()
        
    }
    
    override func viewWillAppear() {
        
        super.viewWillAppear()
        
        // register to receive window delegate calls
        view.window?.delegate = self
        
        view.window?.title = "OTP Consumer {\(viewModel.identifierCid.uuidString)}"
        
    }
    
    /**
     Configure the collection view for displaying points.
    */
    private func configureCollectionView() {
        
        // the collection view should look at this controller for its data source and delegate
        pointsCollectionView.dataSource = self
        
        // do not allow selection
        pointsCollectionView.isSelectable = false
        pointsCollectionView.allowsEmptySelection = false
        pointsCollectionView.allowsMultipleSelection = false
        
        // register the item to be displayed
        pointsCollectionView.register(NSNib(nibNamed: ConsumerPointItem.nibName, bundle: nil), forItemWithIdentifier: ConsumerPointItem.identifier)
        
        configureCollectionViewFlowLayout()
        
    }
    
    /**
     Configure the layout of the collection view.
    */
    func configureCollectionViewFlowLayout() {
        
        let flowLayout = NSCollectionViewFlowLayout()
        
        // the minimum space between items
        flowLayout.minimumInteritemSpacing = 10.0
        flowLayout.minimumLineSpacing = 10.0
        
        // the space between sections
        flowLayout.sectionInset = NSEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0)
        
        // the item size
        flowLayout.itemSize = ConsumerPointItem.itemSize
        
        pointsCollectionView.collectionViewLayout = flowLayout
        
    }
    
    /**
     Prepares the user interface for text fields.
    */
    private func prepareTextFields() {
        
        // add a name
        name.stringValue = "OTPAnalyzerConsumer"
        
    }
    
    /**
     Prepares the user interface for all popups.
    */
    private func preparePopups() {
        
        // add titles for all IP Mode cases
        ipMode.removeAllItems()
        ipMode.addItems(withTitles: OTPIPMode.titles)
        
        // select OTP-4
        ipMode.selectItem(at: 0)

    }
    
    /**
     Prepares the user interface for the system button.
    */
    private func prepareSystemsButton() {
        
        let observedSystemNumbers = viewModel.observedSystemNumbers
        
        switch observedSystemNumbers.count {
        case 0:
            systems.title = "None"
        case let x where x < 5:
            systems.title = "\(observedSystemNumbers.map { "\($0)" }.joined(separator: ", "))"
        default:
            systems.title = "Many"
        }

    }
    
    /**
     Prepares the user interface for all popups.
    */
    private func prepareInterfacesPopup() {
        
        // remove all existing items
        interface.removeAllItems()

        var titles = [(title: String, shortTitle: String)]()
        for interface in interfaces {
            
            if let existingIndex = titles.firstIndex(where: { $0.shortTitle == interface.name }) {
                
                // this interface name already exists, so add the new address to it
                let newTitle = titles[existingIndex].title + ", \(interface.address ?? "??")"
                titles[existingIndex].title = newTitle
                
            } else {
                
                // this interface name is new, so add its title and the address
                let newInterface = (title: "\(interface.name) | \(interface.address ?? "??")", shortTitle: interface.name)
                titles.append(newInterface)
                
            }
            
        }

        // loop through all titles
        for title in titles {
            
            // create a menu item with the title, and a represented object with the short title for close popups
            let menuItem = NSMenuItem(title: title.title, action: nil, keyEquivalent: "")
            menuItem.representedObject = [ShortTitleCell.shortTitle:title.shortTitle]
            interface.menu?.addItem(menuItem)
            
        }
        
        // if an interface was previously selected, and is it still available, select it
        if let interfaceName = viewModel.interfaceName, let selectedIndex = titles.firstIndex(where: { $0.shortTitle == interfaceName }) {
            interface.selectItem(at: selectedIndex)
        } else if let interface = interfaces.first {
            // the first interface found should be used
            viewModel.interfaceName = interface.name
        }
        
    }
    
    /**
     Called whenever interfaces have been discovered.
    */
    func discovered(interfaces: [Interface]) {

        if let interfaceName = viewModel.interfaceName, viewModel.started, !interfaces.contains(where: { $0.name == interfaceName }) {
            
            // the interface selected no longer exists, so stop this consumer
            viewModel.stopConsumer()
            
        }
        
        // update discovered interfaces
        self.interfaces = interfaces
        
        // add titles for all interfaces
        prepareInterfacesPopup()
        
    }
    
    /**
     Stops this consumer and optionally dismisses the view controller.
     
     - Parameters:
         - close: Whether the controller should be closed after stopping this consumer.
     
    */
    func stop(close: Bool) {

        // stop the consumer
        if viewModel.started {
            startStopConsumer(self)
        }
        
        // close if requested
        if close {
            view.window?.close()
        }
        
    }
    
    /**
     Called when a new view controller is presented via a segue.
    */
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        
        // get the destination controller
        guard let controller = segue.destinationController as? ConsumerSystemsController else { return }

        controller.observedSystemNumbers = viewModel.observedSystemNumbers
        controller.discoveredSystemNumbers = viewModel.discoveredSystemNumbers
        
        // register to receive consumer systems controller notifications
        controller.delegate = self
        
    }

    /**
     Starts the consumer sending network data.
     
     - Parameters:
        - sender: The button sending this action.
     
    */
    @IBAction func startStopConsumer(_ sender: AnyObject) {
        
        if viewModel.started {
        
            // attempt to stop the consumer
            viewModel.stopConsumer()

        } else {
            
            // start the consumer

            // get the ip mode
            let ipMode = OTPIPMode.allCases[self.ipMode.indexOfSelectedItem]

            // get all checked modules which should be observed
            var moduleTypes = [OTPModule.Type]()
            if modulePos.checked { moduleTypes.append(OTPModulePosition.self) }
            if modulePosVelAccel.checked { moduleTypes.append(OTPModulePositionVelAccel.self) }
            if moduleRot.checked { moduleTypes.append(OTPModuleRotation.self) }
            if moduleRotVelAccel.checked { moduleTypes.append(OTPModuleRotationVelAccel.self) }
            if moduleScale.checked { moduleTypes.append(OTPModuleScale.self) }
            if moduleReferenceFrame.checked { moduleTypes.append(OTPModuleReferenceFrame.self) }
 
            // attempt to start the consumer
            viewModel.startConsumer(name: name.stringValue, ipMode: ipMode, moduleTypes: moduleTypes, interval: Self.delegateInterval, logErrors: logErrors.checked, logDebug: logDebug.checked, logSocket: logDebugSocket.checked)
            
            // update buttons
            self.ipMode.isEnabled = false
            self.interface.isEnabled = false
            self.reset.isEnabled = true
            self.requestNames.isEnabled = true

        }
        
        // enable/disable buttons
        self.requestNames.isEnabled = viewModel.started
        
        // update the button title
        startStopButton.title = viewModel.started ? "Stop" : "Start"

    }
    
    /**
     Resets the consumer, creating a new identifier and removing all points.
     
     - Parameters:
        - sender: The button sending this action.
     
    */
    @IBAction func resetConsumer(_ sender: AnyObject) {
        
        viewModel.resetConsumer()
        
        // update buttons
        self.ipMode.isEnabled = true
        self.interface.isEnabled = true
        self.reset.isEnabled = false
        self.requestNames.isEnabled = false
        
        // update the button title
        startStopButton.title = "Start"
        
    }
    
    /**
     Changes whether to log for the selected check button.
     
     - Parameters:
        - sender: The button sending this action.
     
    */
    @IBAction func changeLogging(_ sender: NSButton) {
        
        switch sender {
        case logErrors:
            viewModel.logErrors(sender.checked)
        case logDebug:
            viewModel.logDebug(sender.checked)
        case logDebugSocket:
            viewModel.logDebugSocket(sender.checked)
        default:
            break
        }
        
    }
    
    /**
     Changes the interface name based on the selected interface item.
     
     - Parameters:
        - sender: The popup button sending this action.
     
    */
    @IBAction func changeInterface(_ sender: NSPopUpButton) {
        
        // get the name for the selected interface
        guard let object = sender.selectedItem?.representedObject as? Dictionary<String, String>, let shortTitle = object[ShortTitleCell.shortTitle] else { return }

        // update the interface name as selected
        viewModel.interfaceName = shortTitle
        
    }
    
    /**
     Changes the observed state of the module associated with this button.
     
     - Parameters:
        - sender: The button sending this action.
     
    */
    @IBAction func changeModuleObserved(_ sender: NSButton) {
        
        // add or remove this module
        var moduleTypes: [OTPModule.Type]
        switch sender {
        case modulePos:
            moduleTypes = [OTPModulePosition.self]
        case modulePosVelAccel:
            moduleTypes = [OTPModulePositionVelAccel.self]
        case moduleRot:
            moduleTypes = [OTPModuleRotation.self]
        case moduleRotVelAccel:
            moduleTypes = [OTPModuleRotationVelAccel.self]
        case moduleScale:
            moduleTypes = [OTPModuleScale.self]
        case moduleReferenceFrame:
            moduleTypes = [OTPModuleReferenceFrame.self]
        default:
            moduleTypes = [OTPModulePosition.self]
        }
        
        sender.checked ? viewModel.addModuleTypes(moduleTypes) : viewModel.removeModuleTypes(moduleTypes)
        
    }
    
    /**
     Requests names from any producers on the network.
     
     - Parameters:
        - sender: The button sending this action.
     
    */
    @IBAction func requestNames(_ sender: NSButton) {
        
        // only request names if the view model is started
        guard viewModel.started else { return }
        
        viewModel.requestNames()
        
    }
    
}

// MARK: -
// MARK: -

/**
 Consumer Model Delegate
 
 Required methods for objects implementing this delegate.

*/

extension ConsumerController: ConsumerModelDelegate {
    
    /**
     Called to notify the delegate that new or changed producers were discovered.
     
     - Parameters:
        - index: The index of this producer in the array of producers, where it has already been added to the table view.
     
    */
    func changedProducer(atIndex index: Int? = nil) {

        DispatchQueue.main.async {

            if let index = index {
                
                let indexes = (0..<self.producersTableView.tableColumns.count)

                // reload the table for this producer
                self.producersTableView.reloadData(forRowIndexes: IndexSet(integer: index), columnIndexes: IndexSet(indexes))
                
            } else {
                
                // reload the whole table
                self.producersTableView.reloadData()
                
            }
            
            // points may need to show the new name of the winning producer
            self.pointsCollectionView.reloadData()
            
        }
        
    }
    
    /**
     Called to notify the delegate that new or changed points were discovered.
    */
    func changedPoints() {
        
        DispatchQueue.main.async {

            // reload the points collection view
            self.pointsCollectionView.reloadData()

        }
        
    }
    
}

// MARK: -
// MARK: -

/**
 Consumer Controller Extension
 
 Extensions to `ConsumerController` to handle table view data source and delegate.

*/

extension ConsumerController: NSTableViewDataSource, NSTableViewDelegate {
    
    /**
     The column identifiers used for this table view.
    */
    private enum ColumnIdentifiers: String {
        case name = "name"
        case cid = "cid"
        case ipAddress = "ipAddress"
        case state = "state"
        case sequenceErrors = "sequenceErrors"
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        viewModel.producers.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        // there must be a column identifier
        guard let identifier = tableColumn?.identifier, let column = ColumnIdentifiers(rawValue: identifier.rawValue) else { return nil }
        
        // get the producer
        let producer = viewModel.producers[row]
            
        // create a text cell view
        let textCellView: NSTableCellView = tableView.makeView(withIdentifier: tableColumn!.identifier, owner: self) as! NSTableCellView

        switch column {
        case .name:
            textCellView.textField?.stringValue = producer.name
        case .cid:
            textCellView.textField?.stringValue = producer.cid.uuidString
        case .ipAddress:
            textCellView.textField?.stringValue = producer.ipAddress
        case .state:
            textCellView.textField?.stringValue = producer.state.rawValue.capitalized
        case .sequenceErrors:
            textCellView.textField?.stringValue = "\(producer.sequenceErrors)"
        }
        
        // the text field should not be editable
        textCellView.textField?.isEditable = false

        return textCellView
        
    }
    
}

// MARK: -
// MARK: -

/**
 Consumer Controller Extension
 
 Extensions to `ConsumerController` to handle collection view data source.

*/

extension ConsumerController: NSCollectionViewDataSource {
    
    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.points.count
    }
    
    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        
        // there must be a valid point item at this index
        guard let item = collectionView.makeItem(withIdentifier: ConsumerPointItem.identifier, for: indexPath) as? ConsumerPointItem else { return NSCollectionViewItem() }

        // get the point
        let point = viewModel.points[indexPath.item]

        // update any point modules
        item.refreshPosition(point.modules.first(where: { $0.moduleIdentifier == OTPModulePosition.identifier }) as? OTPModulePosition)
        item.refreshPositionVelAccel(point.modules.first(where: { $0.moduleIdentifier == OTPModulePositionVelAccel.identifier }) as? OTPModulePositionVelAccel)
        item.refreshRotation(point.modules.first(where: { $0.moduleIdentifier == OTPModuleRotation.identifier }) as? OTPModuleRotation)
        item.refreshRotationVelAccel(point.modules.first(where: { $0.moduleIdentifier == OTPModuleRotationVelAccel.identifier }) as? OTPModuleRotationVelAccel)
        item.refreshScale(point.modules.first(where: { $0.moduleIdentifier == OTPModuleScale.identifier }) as? OTPModuleScale)
        item.refreshReferenceFrame(point.modules.first(where: { $0.moduleIdentifier == OTPModuleReferenceFrame.identifier }) as? OTPModuleReferenceFrame)
        
        // update the point properties
        item.address.stringValue = point.address.description
        item.priority.stringValue = "\(point.priority)"
        item.name.stringValue = point.name
        
        // if there is a winning producer display its details
        if let cid = point.cid, let producerName = viewModel.producers.first(where: { $0.cid == cid })?.name {
            item.producerName.stringValue = producerName
            item.producerCID.stringValue = cid.uuidString
        } else {
            item.producerName.stringValue = "Merge"
            item.producerCID.stringValue = "N/A"
        }

        return item
        
    }
    
}

// MARK: -
// MARK: -

/**
 Consumer Controller Extension
 
 Extensions to `ConsumerController` to handle text field delegate notifications.

*/

extension ConsumerController: NSTextFieldDelegate {
    
    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        
        let string = fieldEditor.string

        switch control {
        case name:
            viewModel.updateConsumerName(string)
        default:
            break
        }
        
        return true
        
    }
    
}

// MARK: -
// MARK: -

/**
 Consumer Controller Extension
 
 Extensions to `ConsumerController` to handle window delegate notifications.

*/

extension ConsumerController: NSWindowDelegate {
    
    func windowWillClose(_ notification: Notification) {
        
        if viewModel.started {
        
            // attempt to stop the consumer
            viewModel.stopConsumer()
            
        }

        // notify the delegate that this consumer controller is closing
        viewModel.controllerDelegate?.closingConsumerController(self)
        
    }
    
}

// MARK: -
// MARK: -

/**
 Consumer Systems Controller Delegate
 
 Required methods for objects implementing this delegate.
 
*/

extension ConsumerController: ConsumerSystemsControllerDelegate {
    
    /**
     Called whenever the observed system numbers changes
     
     - Parameters:
        - systemNumbers: The system numbers to be observed. An empty array measn all system numbers should be observed.
     
    */
    func shouldObserveSystemNumbers(_ systemNumbers: [OTPSystemNumber]) {
        
        viewModel.observeSystemNumbers(systemNumbers)

        // prepare the systems button
        prepareSystemsButton()
        
    }
    
}

// MARK: -
// MARK: -

/**
 Log Delegate
 
 Required methods for objects implementing this delegate.
 
*/

extension ConsumerController: LogDelegate {

    /**
     Called whenever logs are changed.
     
     - Parameters:
        - message: The log message.
     
    */
    func newLogMessage(_ message: String) {

        DispatchQueue.main.async {
        
            // ensure we have text storage
            guard let textStorage = self.logging.textStorage else { return }

            // begin editing
            textStorage.beginEditing()
            
            // append the message passed with the log attributes
            textStorage.append(NSAttributedString(string: message, attributes: Log.attributes))

            // if the length is greater than the maximum allowed remove the excess
            if textStorage.length > Log.maxSize {
                textStorage.deleteCharacters(in: NSMakeRange(0, message.count))
            }
            
            // end editing
            textStorage.endEditing()
            
            // scroll so the new line is in view
            self.logging.scrollToEndOfDocument(nil)
            
        }

    }
    
    /**
     Called whenever logs are cleared.
    */
    func clearLogs() {

        DispatchQueue.main.async {
        
            // ensure we have text storage
            guard let textStorage = self.logging.textStorage else { return }
            
            // begin editing
            textStorage.beginEditing()
            
            // remove all characters
            textStorage.deleteCharacters(in: NSMakeRange(0, textStorage.length))
            
            // end editing to apply changes
            textStorage.endEditing()
            
        }
        
    }
    
}

